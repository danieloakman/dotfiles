# Dotfiles

My NixOS configuration files and dotfiles.

General dotfiles are kept in the *files/home* directory. *files/\** is for other files outside of the home directory.

See the [shell script readme](files/home/.shell_scripts/README.md) file for more information on utilising the shell scripts.

## Intro

Now that the etc/nixos/configuration.nix file has been moved to ~/nixos AND it's been refactored to be a flake. We need to rebuild the OS as a flake with:
```bash
sudo nixos-rebuild switch --flake ./#HOST_NAME
# Or
nh os swtich # If the command is available and the $FLAKE variable is set.
```

## Development or making changes

- When updating the flake, i.e. the `flake.lock` file, always make a new branch for those changes.
- Small changes can be made directly to the `main` branch.
- Otherwise large features should have a new branch.

## Secrets

#### See https://www.youtube.com/watch?v=G5f6GC7SnhU for more info if needed.
Secrets file is located at *./secrets/secret.yaml* and it's encrypted.
- To edit: `sops secrets/secret.yaml`. This should open nano with the unencrypted file, which you can make changes to. Save and exit, then commit the file.
- Access to secrets in builds is done like:
```nix
text = ''
  echo ${config.sops.secrets.mySecret.path}
  # or
  echo ${config.sops.secrets."path/to/secret".path}
'';
```


## Notes

* Note the *#HOST_NAME*, this references the name of the config in `nixosConfigurations` within *~/nixos/flake.nix*
* You can run `man home-configuration.nix` to get a list of useful home-manager settings and configurations.
* When making new nix files, **make sure to commit them first**, otherwise nix will not be able to find them.
* */boot/kernels* may occasionally fill up with unused linux kernels and need to be manually cleaned up, i.e. `sudo rm /boot/kernels/*6.6.33*`
* Nix caches build results, so if no files have changed, running a build again will produce the same output or error. Keep this in mine when trying to fix an error like the */boot* disk space issue.
* Make sure a new derivation is actually made to the boot list. Doing `nh os boot` from within a devenv shell or other container will not make a new derivation.
