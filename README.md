# Dotfiles

My NixOS & Nix-darwin configuration files and dotfiles.

Shell aliases, functions, and session env live in home-manager modules under `modules/programs/` (especially `shell.nix` and `zsh.nix`). Assets and a few plain files (e.g. SSH config) live under `files/`.

## Directory structure

Single unified flake for NixOS and nix-darwin (no separate `linux/` or `darwin/` trees):

- `flake.nix` — flake entry point; `nixosConfigurations` and `darwinConfigurations` live here.
- `hosts/` — per-machine host modules (`akatosh`, `azura`, `mara`, `boethiah`, …).
- `modules/` — shared Nix modules; platform-specific files use `.linux.nix` or `.darwin.nix` suffixes.
- `files/` — assets and plain files managed via home-manager (e.g. `files/home/.ssh/config`, wallpapers under `files/assets/`).
- `secrets/` — sops-encrypted secrets.

## Building

We need to rebuild the OS as a flake with:
```bash
sudo nixos-rebuild switch --flake ./#HOST_NAME
# Or, from this repo (preferred):
just switch
# nh needs an explicit flake path when not using just:
nh os switch .      # Linux
nh darwin switch .  # macOS
```

## Development or making changes

- When updating the flake, i.e. the `flake.lock` file, always make a new branch for those changes.
- Small changes can be made directly to the `main` branch.
- Otherwise large features should have a new branch.
- Modules live in `./modules`. Files named `*.linux.nix` or `*.darwin.nix` are only imported on that platform; other modules are shared. Files matching `*/_*.nix` and `flake.nix` are skipped.
- Most modules should be defined with a set of option(s) to enable or tweak the module to suit the host machine. That is unless the module is always loaded on every host.

## Secrets

#### See https://www.youtube.com/watch?v=G5f6GC7SnhU for more info if needed.
Secrets file is located at *./secrets/secrets.yaml* and is encrypted.
Also need to have your age secret key present in `~/.config/sops/age/keys.txt`
- To edit: `sops secrets/secrets.yaml` OR `just edit-secrets`. This should open nano with the unencrypted file, which you can make changes to. Save and exit, then commit the file.
- Access to secrets in builds is done like:
```nix
text = ''
  echo ${config.sops.secrets.mySecret.path}
  # or
  echo ${config.sops.secrets."path/to/secret".path}
'';
```


## Notes

* Note the *#HOST_NAME*, this references a key in `nixosConfigurations` or `darwinConfigurations` in `flake.nix` (e.g. `./#akatosh`, `./#boethiah`).
* You can run `man home-configuration.nix` to get a list of useful home-manager settings and configurations.
* When making new nix files, **make sure to commit them first**, otherwise nix will not be able to find them.
* */boot/kernels* may occasionally fill up with unused linux kernels and need to be manually cleaned up, i.e. `sudo rm /boot/kernels/*6.6.33*`
* Nix caches build results, so if no files have changed, running a build again will produce the same output or error. Keep this in mind when trying to fix an error like the */boot* disk space issue.
* Make sure a new derivation is actually made to the boot list. Doing `nh os boot` from within a devenv shell or other container will not make a new derivation.
