# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ inputs, config, pkgs, ... }:
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../modules/system.nix
    ../../modules/ssh.nix
    ../../modules/desktop-pkgs.nix
    ../../modules/gnome
    ../../modules/power-management.nix
    ../../modules/mobile-dev.nix
    ../../modules/games.nix
    ../../modules/stylix.nix
    ../../modules/dev.nix
    ../../modules/docker.nix
    ../../modules/rofi.nix
    ../../modules/syncthing.nix
    ../../modules/wakeonlan.nix
  ];

  # Bootloader
  boot.loader = {
    efi.canTouchEfiVariables = true;
    grub = {
      device = "nodev";
      enable = true;
      efiSupport = true;
      useOSProber = true;
    };
  };

  networking.hostName = "akatosh"; # Define your hostname.

  # Required config for imported modules:
  stylix.image = pkgs.fetchurl {
    url = "https://images5.alphacoders.com/131/1315219.jpeg";
    sha256 = "sha256-BldA8qVEfFCqkHgG/reI3T++D+l91In7gABcmwv3e0g=";
  };
  # home-manager.users.${env.user}.wayland.windowManager.hyprland.settings.monitor = [
  #   "DP-1, 1920x1080, 0x0, 1.0"
  #   # other monitors needed if hyprland were to be used on this host
  # ];

  hardware = {
    enableRedistributableFirmware = true;

    # This might not be needed, as it's to do with cpu graphics, which this system doesn't have. Leave it for now.
    graphics.enable = true;
    graphics.enable32Bit = true;

    # See https://nixos.wiki/wiki/Nvidia for more information.
    nvidia = {
      modesetting.enable = true;
      powerManagement.enable = true; # Fix for issues after waking from suspend
      package = config.boot.kernelPackages.nvidiaPackages.production;
      open = false;
    };
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}
