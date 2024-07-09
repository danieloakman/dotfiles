# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ lib, inputs, config, pkgs, ... }:
let
  env = {
    isLaptop = true;
    isOnWayland = true;
  };
in
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    (import ../../modules/system.nix { inherit lib inputs config pkgs env; })
    inputs.home-manager.nixosModules.home-manager
    ../../modules/user.nix
    (import ../../modules/power-management.nix { inherit env; })
    ../../modules/hyprland.nix
    # ../../modules/gnome.nix
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "djo-tiny-laptop"; # Define your hostname. `echo $HOST`

  # Enable fingerprint reader:
  services.fprintd = {
    enable = true;
    package = pkgs.fprintd-tod;
    tod = {
      enable = true;
      driver = pkgs.libfprint-2-tod1-goodix; # Specifc driver, works for dell xps 13.
    };
  };

  # Enable Linux vendor firmware service: https://fwupd.org/
  # Use use `fwupdmgr` to perform updates. 
  services.fwupd.enable = true;

  hardware = {
    enableRedistributableFirmware = true;
    graphics = {
      enable = true;
      enable32Bit = true;
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}
