# Gnome configuration

{ config, lib, pkgs, modulesPath, ... }:
{
  # Enable the GNOME Desktop Environment.
  services.xserver = {
    displayManager = {
      gdm.enable = true;
      # autoLogin = {
      #   enable = true;
      #   user = "dano";
      # };
    };
    desktopManager.gnome.enable = true;
  };

  # Exclude particular gnome specific packages
  environment.gnome.excludePackages = (with pkgs; [
    # gnome-photos
    gnome-tour
    # gnome-connections
    orca
  ]) ++ (with pkgs.gnome; [
    cheese # webcam tool
    gnome-music
    # gedit # text editor
    epiphany # web browser
    geary # email reader
    gnome-characters
    tali # poker game
    iagno # go game
    hitori # sudoku game
    atomix # puzzle game
    yelp # Help view
    gnome-contacts
    gnome-initial-setup
    totem
    atomix
    evince
    gnome-maps
    gnome-weather
    sushi
    gnome-calendar
  ]);
  services.gnome.games.enable = false; # Disable all games

  environment = {
    systemPackages = with pkgs; [
      networkmanager
      networkmanagerapplet # Provides `nmi-connection-editor` command
      gnome.networkmanager-openvpn
      gnome.gnome-tweaks
      gnomeExtensions.appindicator
      gnomeExtensions.tailscale-status
      gnome-frog # OCR tool
      gnomeExtensions.touch-x
      # The following all didn't work on nixos or was not compatible with gnome v45
      # gnomeExtensions.enhanced-osk # TODO: remove this comment if gjs-osk is good
      # gnomeExtensions.gjs-osk
      # gnomeExtensions.simple-monitor # TODO: try this out
    ];
  };
}
