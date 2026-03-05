# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, lib, modulesPath, ... }:

{
  imports = [
    # Include the results of the hardware scan.
    (modulesPath + "/installer/scan/not-detected.nix")

    ../modules/ssh.nix
    ../modules/dev
    ../modules/mobile-dev.nix
    ../modules/docker.nix
    ../modules/syncthing.nix
    ../modules/power-management.nix
    # ../modules/wakeonlan.nix # TODO: re-enable when mara is connected via ethernet cable
    ../modules/zsh.nix
    ../modules/network.nix
    # ../modules/comma.nix
    ../modules/tmux.nix
    ../modules/btop.nix
    ../modules/scripts
    ../modules/gws.nix

    ../modules/programs

    ../modules/services
  ];

  boot = {
    initrd = {
      availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
      kernelModules = [ ];
    };
    kernelModules = [ "kvm-intel" ];
    extraModulePackages = [ ];
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/57e37ff0-9c7c-4aa4-9955-cb7ad0d7cca3";
      fsType = "ext4";
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/265B-6120";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };
    "/run/media/HDD_1" = {
      device = "/dev/disk/by-uuid/567A58A4260BD810";
      fsType = "ntfs";
    };
  };
  systemd.tmpfiles.rules = [
    "d /run/media/HDD_1 0770 root storage -"
  ];

  services.immich.mediaLocation = "/run/media/HDD_1/immich";
  services.paperless.mediaDir = "/run/media/HDD_1/paperless";

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
  # networking.interfaces.eno1.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp0s20f3.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # Bootloader.
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  networking.hostName = "mara"; # Define your hostname.

  # Configure console keymap
  console.keyMap = "us";

  services.tailscale.extraSetFlags = [
    "--advertise-exit-node"
    "--exit-node-allow-lan-access"
  ];

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
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
}
