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

gc:
    nix-collect-garbage -d

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

# Schedule `nh os boot` once at HH:MM as your user (not root — nh refuses root).
# Overnight the build can finish; elevation may fail without a TTY. Re-run `just boot`
# in the morning to reuse the store and enter your password.
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
    unit=dotfiles-nh-boot
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
    systemctl --user stop "${unit}.timer" 2>/dev/null || true
    systemctl --user stop "${unit}.service" 2>/dev/null || true
    systemd-run --user \
      --collect \
      --unit="$unit" \
      --description="Scheduled nh os boot (${repo})" \
      --working-directory="$repo" \
      --property='Environment=PATH=/run/wrappers/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin' \
      --on-calendar="$calendar" \
      "$nh" os boot "$repo"
    echo "Scheduled nh os boot for ${calendar} (local, user). Cancel: just boot-at-cancel"

[linux]
boot-at-cancel:
    systemctl --user stop dotfiles-nh-boot.timer 2>/dev/null || true
    systemctl --user stop dotfiles-nh-boot.service 2>/dev/null || true
    @echo "Cancelled scheduled nh os boot (if any)."

[linux]
switch:
    nh os switch {{ repo }}

[macos]
switch:
    # sudo darwin-rebuild switch --flake .
    nh darwin switch {{ repo }}

[linux]
test:
    nh os test {{ repo }}

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

[linux]
clean:
    nh clean all -a --keep 1

# Rank profile packages by least-recent binary access; hint modules/hosts refs.
# Examples: `just unused-bins` | `just unused-bins --limit 20` | `just unused-bins --all`
[linux, positional-arguments]
unused-bins *args:
    @{{ repo }}/scripts/unused-bins.sh "$@"
