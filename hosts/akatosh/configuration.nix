# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ inputs, config, ... }:
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../modules/system.nix
    ../../modules/desktop-pkgs.nix
    ../../modules/gnome
    ../../modules/power-management.nix
    ../../modules/mobile-dev.nix
    ../../modules/games.nix
    inputs.stylix.nixosModules.stylix
    ../../modules/stylix.nix
    ../../modules/dev.nix
    ../../modules/docker.nix
    ../../modules/rofi.nix
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

  networking.hostName = "akatosh"; # Define your hostname.

  # Wake-on-LAN configuration for ethernet interface
  networking.interfaces.enp0s31f6 = {
    useDHCP = true;
    wakeOnLan.enable = true;
  };

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
