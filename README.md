# NixOS

## Intro

Now that the etc/nixos/configuration.nix file has been moved to ~/nixos AND it's been refactored to be a flake. We need to rebuild the OS as a flake with:
```bash
sudo nixos-rebuild switch --flake ./#HOST_NAME
# Or
nixos-switch # If the alias is available.
```

# Development or making changes

- When updating the flake, i.e. the `flake.lock` file, always make a new branch for those changes.
- Small changes can be made directly to the `main` branch.
- Otherwise large features should have a new branch.

## Notes

* Note the *#HOST_NAME*, this references the name of the config in `nixosConfigurations` within *~/nixos/flake.nix*
* You can run `man home-configuration.nix` to get a list of useful home-manager settings and configurations.
* When making new nix files, **make sure to commit them first**, otherwise nix will not be able to find them.
* */boot/kernels* may occasionally fill up with unused linux kernels and need to be manually cleaned up, i.e. `sudo rm /boot/kernels/*6.6.33*`
* Nix caches build results, so if no files have changed, running a build again will produce the same output or error. Keep this in mine when trying to fix an error like the */boot* disk space issue.
