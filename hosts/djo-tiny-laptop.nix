# Deprecated: No longer have this computer as it was Tiny Technologies'.

# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ lib, inputs, config, pkgs, env, modulesPath, ... }:
{
  boot = {
    initrd = {
      availableKernelModules = [ "xhci_pci" "thunderbolt" "vmd" "nvme" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
      kernelModules = [ ];
    };
    kernelModules = [ "kvm-intel" ];
    extraModulePackages = [ ];
  };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/9c8b7313-0161-4435-a775-1a36b47978e9";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/1977-CC9F";
    fsType = "vfat";
  };

  swapDevices = [ ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp0s20f3.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  imports = [
    # Include the results of the hardware scan.
    (modulesPath + "/installer/scan/not-detected.nix")

    (import ../modules/system.nix { inherit lib inputs config pkgs env; })
    ../modules/desktop-pkgs.nix
    ../modules/user.nix
    ../modules/gnome
    (import ../modules/power-management.nix { inherit env; })
    (import ../modules/stylix.nix { inherit pkgs env; })
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "djo-tiny-laptop"; # Define your hostname. `echo $HOST`

  # Required config for imported modules:
  stylix.image = pkgs.fetchurl {
    url = "https://pixeldrain.com/api/file/CWZC2L9b";
    sha256 = "sha256-m8c4ulgOQGBjNcCzW2RNJcLN9ewicFW1CIyHbG3+wmA=";
  };
  # home-manager.users.${env.user}.wayland.windowManager.hyprland.settings.monitor = [];

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
