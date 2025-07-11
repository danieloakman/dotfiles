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
    ../../modules/power-management.nix
    inputs.stylix.nixosModules.stylix
    ../../modules/stylix.nix
    ../../modules/dev.nix
    ../../modules/rofi.nix
    ../../modules/syncthing.nix
    ../../modules/docker.nix

    # Window manager:
    # ../../modules/gnome
    ../../modules/hyprland.nix
  ];

  # Environment configuration
  config.env = {
    user = "dano";
    isLaptop = true;
    isOnWayland = true;
    hasGPU = false;
    wallpaper = pkgs.fetchurl {
      url = "https://pixeldrain.com/api/file/UELyHDVS";
      sha256 = "sha256-1PVA1OhbAA3GT9eG3ZzybI8xBljqyq3TaMyMKwpbTLk";
    };
    hyprland = {
      monitor = [
        "eDP-1, 1366x768, 0x0, 1.0"
      ];
    };
  };

  # Bootloader.
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
    useOSProber = true;
  };

  networking.hostName = "azura"; # Define your hostname. `echo $HOST`

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?

  # Configure remote builders
  nix.buildMachines = [{
    hostName = "akatosh";
    system = "x86_64-linux";
    maxJobs = 8;
    speedFactor = 2;
    supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
    mandatoryFeatures = [ ];
  }];
}
