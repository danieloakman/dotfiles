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
    profiles.dev-workstation.enable = true;
    desktop = {
      hyprland = {
        enable = true;
        monitors = [
          "eDP-1, 1366x768, 0x0, 1.0"
        ];
        hyprpaper.wallpaper = wallpaperPath;
        onscreen-keyboard.enable = true;
      };
      ui-shell = "ags";
    };
    programs = {
      desktop-pkgs.enable = true;
    };
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

  networking.hostName = "azura";

  system.stateVersion = "23.05";

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
