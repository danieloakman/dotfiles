# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, config, pkgs, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../modules/system.nix
    ../../modules/user.nix
    ../../modules/gnome.nix
    ../../modules/desktop-power-management.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  # Bootloader
  boot.loader = {
    # systemd-boot.enable = true; # TODO: remove this line and remove the already existing boot loader that this option creates.
    efi.canTouchEfiVariables = true;
    grub = {
      device = "nodev";
      enable = true;
      efiSupport = true;
      useOSProber = true;
    };
  };

  networking.hostName = "djo-personal-desktop"; # Define your hostname.

  hardware.enableRedistributableFirmware = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?

}
