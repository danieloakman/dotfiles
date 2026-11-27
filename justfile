repo := justfile_directory()

default:
    @just --list

fmt:
    nixpkgs-fmt . && nix shell 'nixpkgs#statix' -c statix fix .

# Fail if formatting would change files (used by CI).
fmt-check:
    nixpkgs-fmt --check .

lint:
    nix shell 'nixpkgs#statix' -c statix check .

edit-secrets:
    nix shell 'nixpkgs#sops' -c sops '{{ repo }}/secrets/secrets.yaml'

# Nix GC via nh (gens + gcroots + store). Prefer these over bare
# `nix-collect-garbage`: that only deletes unreachable store paths; with `-d`
# it also drops old profile gens it knows about, but misses direnv/auto
# gcroots and never removes a repo `result` symlink (which pins a closure).
# Use gc-hard when / is nearly full before a large rebuild.

# Keep 2 gens / last 3d; drop repo result; print df before/after.
[linux]
gc:
    #!/usr/bin/env bash
    set -euo pipefail
    df -h / | tail -1
    rm -f '{{ repo }}/result'
    sudo nh clean all --keep-since 3d --keep 2
    df -h / | tail -1

# Keep 3 gens / last 5d (same policy as mara nh.clean timer).
[linux]
gc-soft:
    #!/usr/bin/env bash
    set -euo pipefail
    df -h / | tail -1
    rm -f '{{ repo }}/result'
    sudo nh clean all --keep-since 5d --keep 3
    df -h / | tail -1

# Current gen only + journal vacuum to 200M. No rollback room.
[linux]
gc-hard:
    #!/usr/bin/env bash
    set -euo pipefail
    df -h / | tail -1
    rm -f '{{ repo }}/result'
    sudo nh clean all --keep 1
    sudo journalctl --vacuum-size=200M
    df -h / | tail -1

# Dry-run of default `just gc`.
[linux]
gc-dry:
    #!/usr/bin/env bash
    set -euo pipefail
    df -h / | tail -1
    if [[ -e '{{ repo }}/result' ]]; then
      echo "would remove {{ repo }}/result (pins a build closure)"
    fi
    sudo nh clean all --keep-since 3d --keep 2 --dry

# Keep 2 gens / last 3d (user profiles).
[macos]
gc:
    #!/usr/bin/env bash
    set -euo pipefail
    rm -f '{{ repo }}/result'
    nh clean user --keep-since 3d --keep 2

# Current user gen only.
[macos]
gc-hard:
    #!/usr/bin/env bash
    set -euo pipefail
    rm -f '{{ repo }}/result'
    nh clean user --keep 1

[positional-arguments]
check *args:
    nix flake check "$@" .

# Evaluate only one host config (default: current hostname). Optional: `just check-host akatosh`.
[linux, positional-arguments]
check-host *host:
    #!/usr/bin/env bash
    set -euo pipefail
    host="${1:-$(hostname)}"
    nix eval --raw ".#nixosConfigurations.${host}.config.system.build.toplevel.drvPath"
    echo

[macos, positional-arguments]
check-host *host:
    #!/usr/bin/env bash
    set -euo pipefail
    host="${1:-$(hostname)}"
    nix eval --raw ".#darwinConfigurations.${host}.system.drvPath"
    echo

# Evaluate every Linux host (drvPath only; no build). Used by CI.
[linux]
check-hosts:
    #!/usr/bin/env bash
    set -euo pipefail
    for host in akatosh azura mara installer; do
      echo "==> ${host}"
      nix eval --raw ".#nixosConfigurations.${host}.config.system.build.toplevel.drvPath"
      echo
    done

# Evaluate every Darwin host (drvPath only; no build). Used by CI.
[macos]
check-hosts:
    #!/usr/bin/env bash
    set -euo pipefail
    for host in boethiah; do
      echo "==> ${host}"
      nix eval --raw ".#darwinConfigurations.${host}.system.drvPath"
      echo
    done

# What CI runs locally for this platform (fmt + lint + all host evals).
ci: fmt-check lint check-hosts

update:
    sudo nix flake update --flake .

# Build the installer ISO and write it to a USB disk (prompts for the device).
[linux]
iso:
    nix build {{ repo }}#iso -o {{ repo }}/result
    {{ repo }}/scripts/write-iso.sh

[linux]
build:
    nh os build {{ repo }}

[macos]
build:
    # sudo darwin-rebuild build --flake .
    nh darwin build {{ repo }}

[linux]
boot:
    nh os boot {{ repo }}
    rm -f {{ repo }}/result

# Build here, then set a remote NixOS host's boot default over SSH.
# `--use-substitutes` lets the target pull missing store paths from
# binary caches instead of copying the whole closure from this machine.
# Host must exist in the flake's nixosConfigurations.
# Default target: dano@<host>.dinosaur-crocodile.ts.net
# Example: `just boot-remote azura` or `just boot-remote azura dano@azura`
[linux, positional-arguments]
boot-remote *args:
    #!/usr/bin/env bash
    set -euo pipefail
    just --justfile "{{ justfile() }}" _remote-os boot "$@"

# Schedule `nh os build` once at HH:MM (user timer; no sudo). Pins GC via repo `result`.
# Morning: `just boot` reuses the store and prompts for your password to set the boot default.
# Example: `just boot-at 12:00`  |  cancel: `just boot-at-cancel`
[linux, positional-arguments]
boot-at *when:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "$#" -ne 1 ]]; then
      echo "usage: just boot-at <HH:MM>" >&2
      exit 1
    fi
    when="$1"
    if [[ "$when" =~ ^[0-9]{1,2}:[0-9]{2}$ ]]; then
      when="${when}:00"
    elif [[ ! "$when" =~ ^[0-9]{1,2}:[0-9]{2}:[0-9]{2}$ ]]; then
      echo "usage: just boot-at <HH:MM>" >&2
      exit 1
    fi
    unit=dotfiles-nh-build
    repo='{{ repo }}'
    nh="$(command -v nh)"
    today="$(date +%F)"
    target_ts="$(date -d "${today} ${when}" +%s)"
    now_ts="$(date +%s)"
    if (( target_ts <= now_ts )); then
      calendar="$(date -d "tomorrow ${when}" '+%F %T')"
    else
      calendar="$(date -d "${today} ${when}" '+%F %T')"
    fi
    # Drop prior build timer and the old boot-unit name if present.
    systemctl --user stop "${unit}.timer" "${unit}.service" \
      dotfiles-nh-boot.timer dotfiles-nh-boot.service 2>/dev/null || true
    systemd-run --user \
      --collect \
      --unit="$unit" \
      --description="Scheduled nh os build (${repo})" \
      --working-directory="$repo" \
      --property='Environment=PATH=/run/wrappers/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin' \
      --on-calendar="$calendar" \
      "$nh" os build "$repo" -o "$repo/result"
    echo "Scheduled nh os build for ${calendar} (local, user). Cancel: just boot-at-cancel"

[linux]
boot-at-cancel:
    systemctl --user stop dotfiles-nh-build.timer dotfiles-nh-build.service \
      dotfiles-nh-boot.timer dotfiles-nh-boot.service 2>/dev/null || true
    @echo "Cancelled scheduled nh os build (if any)."

[linux]
switch:
    nh os switch {{ repo }}
    rm -f {{ repo }}/result

# Like `just switch`, but deploy a remote NixOS host over SSH.
# Example: `just switch-remote azura` or `just switch-remote azura dano@azura`
[linux, positional-arguments]
switch-remote *args:
    #!/usr/bin/env bash
    set -euo pipefail
    just --justfile "{{ justfile() }}" _remote-os switch "$@"

# Shared remote NixOS deploy. cmd is boot or switch.
# Usage: just _remote-os <boot|switch> <host> [target]
[linux, positional-arguments, private]
_remote-os *args:
    #!/usr/bin/env bash
    set -euo pipefail
    cmd="${1:-}"
    if [[ "$#" -lt 2 || "$#" -gt 3 || ! "$cmd" =~ ^(boot|switch)$ ]]; then
      echo "usage: just ${cmd:-boot}-remote <host> [target]" >&2
      exit 1
    fi
    host="$2"
    target="${3:-dano@${host}.dinosaur-crocodile.ts.net}"
    repo='{{ repo }}'
    hosts_json="$(nix eval "${repo}#nixosConfigurations" --apply builtins.attrNames --json)"
    case "$hosts_json" in
      *'"'"$host"'"'*) ;;
      *)
        echo "unknown NixOS host: ${host}" >&2
        echo "  valid: ${hosts_json}" >&2
        exit 1
        ;;
    esac
    nh os "$cmd" "$repo" \
      -H "$host" \
      --target-host "$target" \
      --use-substitutes
    rm -f "$repo/result"

[macos]
switch:
    # sudo darwin-rebuild switch --flake .
    nh darwin switch {{ repo }}
    rm -f {{ repo }}/result

[linux]
test:
    nh os test {{ repo }}
    rm -f {{ repo }}/result

[linux]
gen-ls:
    nixos-rebuild list-generations

[macos]
gen-ls:
    sudo darwin-rebuild --list-generations --flake .

[linux, positional-arguments]
gen-rm *gens:
    #! /usr/bin/env bash
    set -euo pipefail
    if [[ -z "$*" ]]; then
        echo "usage: just gen-rm <gen> [<gen> ...]" >&2
        echo "  gen: generation number (ID column) from \`just list-generations\`" >&2
        exit 1
    fi
    sudo nix-env -p /nix/var/nix/profiles/system --delete-generations "$@"

# Rank profile packages by least-recent binary access; hint modules/hosts refs.
# Examples: `just unused-bins` | `just unused-bins --limit 20` | `just unused-bins --all`
[linux, positional-arguments]
unused-bins *args:
    @{{ repo }}/scripts/unused-bins.sh "$@"
