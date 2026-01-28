# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ env, config, lib, modulesPath, ... }:
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

    ../modules/ssh.nix
    ../modules/desktop-pkgs.nix
    ../modules/power-management.nix
    ../modules/dev.nix
    ../modules/mobile-dev.nix
    ../modules/rofi.nix
    ../modules/syncthing.nix
    ../modules/docker.nix
    ../modules/stylix.nix
    ../modules/zsh.nix
    ../modules/network.nix
    ../modules/kitty.nix

    # ../modules/gnome
    ../modules/hyprland
  ];

  # Bootloader.
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
    useOSProber = true;
  };

  networking.hostName = "azura"; # Define your hostname. `echo $HOST`

  # Required config for imported modules:
  stylix.image = ../files/assets/azura-wallpaper.jpeg;
  home-manager.users.${env.user} = {
    wayland.windowManager.hyprland.settings = {
      monitor = [
        "eDP-1, 1366x768, 0x0, 1.0"
      ];
      # Window rules
      windowrulev2 = [
        "workspace 1, class:^(vivaldi-bin)$"
        "workspace 2, class:^(Cursor)$"
        "workspace 2, class:^(code)$"
        "workspace 3, class:^(Spotify)$"
        "workspace 4, class:^(obsidian)$"
        "workspace 5, class:^(Discord)$"
        "workspace 6, class:^(Steam)$"
      ];
    };

    services.hyprpaper.settings =
      let
        wallpaperPath = "${env.home}/repos/personal/dotfiles/files/assets/azura-wallpaper.jpeg";
      in
      {
        preload = [ wallpaperPath ];
        wallpaper = [ "eDP-1,${wallpaperPath}" ];
      };
  };

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
