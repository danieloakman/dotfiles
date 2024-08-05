# Gnome configuration

{ pkgs, ... }:
{
  services = {
    xserver = {
      # Enable the GNOME Desktop Environment.
      displayManager = {
        gdm.enable = true;
        # autoLogin = {
        #   enable = true;
        #   user = env.user;
        # };
      };
      desktopManager.gnome.enable = true;
    };

    gnome.games.enable = false; # Disable all games
  };

  environment = {
    # Exclude particular gnome specific packages
    gnome.excludePackages = (with pkgs; [
      # gnome-photos
      gnome-tour
      # gnome-connections
      orca # Screen reader
      epiphany # web browser
      geary # email reader
      yelp # Help view
      totem
      evince
      sushi
      gnome-calendar # We use evolution instead
    ]) ++ (with pkgs.gnome; [
      gnome-music
      # gedit # text editor
      gnome-characters
      tali # poker game
      iagno # go game
      hitori # sudoku game
      atomix # puzzle game
      gnome-contacts
      gnome-initial-setup
      atomix
      gnome-maps
      gnome-weather
    ]);

    systemPackages = with pkgs; [
      networkmanager
      networkmanagerapplet # Provides `nmi-connection-editor` command
      gnome.networkmanager-openvpn
      gnome-tweaks
      gnome-terminal
      # gnome.pomodoro # Not updated
      # gnome.cheese # Web cam tool
      gnomeExtensions.appindicator
      gnomeExtensions.tailscale-status
      gnome-frog # OCR tool
      # gnomeExtensions.touch-x Not updated
      # gnomeExtensions.system-monitor-next # "System Monitor" is better for now
      gnomeExtensions.syncthing-indicator
      # The following all didn't work on nixos or was not compatible with gnome v45
      # gnomeExtensions.valent
      # gnomeExtensions.enhanced-osk # TODO: remove this comment if gjs-osk is good
      # gnomeExtensions.gjs-osk
    ];
  };

  programs = {
    # This seemes to be the best all round email and calendar app for gnome.
    evolution = {
      enable = true;
      plugins = with pkgs; [
        evolution-ews # This https://kb.iu.edu/d/bghs was the only way I found to get connecting to my frogco email working, i.e. office365
      ];
    };
  };
}
