# Notes on nixos and home-manager

Now that the etc/nixos/configuration.nix file has been moved to ~/nixos AND it's been refactored to be a flake. We need to rebuild the OS as a flake with:
```bash
sudo nixos-rebuild switch --flake ./#myNixos
```
* Note the *#myNixos*, this references the name of the flake within *~/nixos/flake.nix*

You can run `man home-configuration.nix` to get a list of useful home-manager settings and configurations.
 