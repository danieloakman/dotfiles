repo := justfile_directory()

default:
    @just --list

fmt:
    nixpkgs-fmt . && nix shell 'nixpkgs#statix' -c statix fix .

lint:
    nix shell 'nixpkgs#statix' -c statix check .

edit-secrets:
    nix shell 'nixpkgs#sops' -c sops '{{ repo }}/secrets/secrets.yaml'

gc:
    nix-collect-garbage -d

[positional-arguments]
check *args:
    nix flake check "$@" .

update:
    sudo nix flake update --flake .

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
