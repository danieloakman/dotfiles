# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ env, config, pkgs, ... }:
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../modules/system.nix
    ../../modules/ssh.nix
    ../../modules/desktop-pkgs.nix
    ../../modules/power-management.nix
    ../../modules/mobile-dev.nix
    ../../modules/games.nix
    ../../modules/stylix.nix
    ../../modules/dev.nix
    ../../modules/docker.nix
    ../../modules/rofi.nix
    ../../modules/syncthing.nix
    ../../modules/wakeonlan.nix
    ../../modules/password-store.nix

    # ../../modules/gnome
    ../../modules/hyprland
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
  home-manager.users.${env.user}.wayland.windowManager.hyprland.settings = {
    monitor = [
      "DVI-D-1, 1920x1080, 0x0, 1.0"
      "DP-2, 3440x1440@144.00Hz, 1920x0, 1.0"
      "HDMI-A-1, 1920x1080, 5360x0, 1.0"
    ];
    # This host basically links its 3 monitors to 3 workspaces:
    workspace = [
      "1, monitor:DVI-D-1"
      "2, monitor:DP-2"
      "3, monitor:HDMI-A-1"
    ];
    # Window rules
    windowrule = [
      "workspace 1, class:^(vivaldi-bin)$"
      "workspace 1, class:^(vivaldi)$"
      "workspace 1, class:^(chromium)$"
      "workspace 1, class:^(chrome)$"
      "workspace 1, class:^(firefox)$"
      "workspace 1, class:^(google-chrome)$"
      "workspace 2, class:^(Cursor)$"
      "workspace 2, class:^(code)$"
      "workspace 3, class:^(Spotify)$"
      "workspace 2, class:^(obsidian)$"
      "workspace 3, class:^(Discord)$"
      "workspace 3, class:^(Steam)$"
    ];
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
