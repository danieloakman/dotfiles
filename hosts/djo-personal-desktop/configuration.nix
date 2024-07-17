# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ lib, inputs, config, pkgs, ... }:
let
  env = {
    isLaptop = false;
    isOnWayland = false;
  };
in
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    inputs.sops-nix.nixosModules.sops
    (import ../../modules/system.nix { inherit lib inputs config pkgs env; })
    ../../modules/desktop-pkgs.nix
    ../../modules/gnome.nix
    (import ../../modules/power-management.nix { inherit env; })
    ../../modules/mobile-dev.nix
    (import ../../modules/games.nix { inherit pkgs; })
  ];

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = /home/dano/.config/sops/age/keys.txt;

    secrets.root_password = {
      owner = config.users.users.dano.name;
    };
  };

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

  hardware = {
    enableRedistributableFirmware = true;
    graphics.enable = true;
    graphics.enable32Bit = true;
    nvidia.modesetting.enable = true;
    nvidia.package = config.boot.kernelPackages.nvidiaPackages.production;
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?

}
