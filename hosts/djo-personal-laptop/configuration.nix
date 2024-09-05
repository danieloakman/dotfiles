# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ lib, inputs, config, pkgs, env, ... }:
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    (import ../../modules/system.nix { inherit lib inputs config pkgs env; })
    ../../modules/desktop-pkgs.nix
    ../../modules/user.nix
    ../../modules/gnome.nix
    (import ../../modules/power-management.nix { inherit env; })
    inputs.stylix.nixosModules.stylix
    (import ../../modules/stylix.nix { inherit pkgs env; })
    ../../modules/dev.nix
  ];

  # Bootloader.
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
    useOSProber = true;
  };

  networking.hostName = "djo-personal-laptop"; # Define your hostname. `echo $HOST`

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}
