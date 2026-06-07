# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ env, config, lib, modulesPath, ... }:
let
  wallpaperPath = ../files/assets/azura-wallpaper.jpeg;
in
{
  boot = {
    initrd.availableKernelModules = [ "xhci_pci" "ehci_pci" "ahci" "usb_storage" "sd_mod" "rtsx_pci_sdmmc" ];
    initrd.kernelModules = [ ];
    kernelModules = [ ];
    extraModulePackages = [ ];
  };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/89883264-d0ef-47f5-87d3-fc975cca3bd3";
    fsType = "ext4";
  };

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 8192; # MB
    }
  ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp0s20u6c2.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp0s25.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlo1.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  imports = [
    # Include the results of the hardware scan.
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  my = {
    desktop = {
      hyprland = {
        enable = true;
        monitors = [
          "eDP-1, 1366x768, 0x0, 1.0"
        ];
        hyprpaper.wallpaper = wallpaperPath;
      };
      uiShell = "ags";
    };
    programs = {
      agents.enable = true;
      devPkgs.enable = true;
      jsPackageSecurity.enable = true;
      claude-code.enable = true;
      rtk.enable = true;
      cursor.enable = true;
      onscreenKeyboard.enable = true;
      gws.enable = true;
      localsend.enable = true;
      desktopPkgs.enable = true;
      kitty.enable = true;
      rofi.enable = true;
      ydotool.enable = true;
      lazyvim = {
        enable = true;
        enableVSCodeKeybinds = true;
      };
    };
    scripts.bun.enable = true;
    services = {
      syncthing.enable = true;
      stylix = {
        enable = true;
        wallpaper = wallpaperPath;
      };
      # docker.enable = true;
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
  nix.buildMachines = [
    {
      hostName = "akatosh";
      system = "x86_64-linux";
      maxJobs = 8;
      speedFactor = 2;
      supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
      mandatoryFeatures = [ ];
    }
    {
      hostName = "mara";
      system = "x86_64-linux";
      maxJobs = 3;
      speedFactor = 2;
      supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
      mandatoryFeatures = [ ];
    }
  ];
}
