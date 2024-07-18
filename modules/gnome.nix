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
        #   user = "dano";
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
    ]) ++ (with pkgs.gnome; [
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
      gnome-calendar # TODO: look into making the calendar settings declarative. As in, I want the same calendar settings as google calendar.
    ]);

    systemPackages = with pkgs; [
      networkmanager
      networkmanagerapplet # Provides `nmi-connection-editor` command
      gnome.networkmanager-openvpn
      gnome.gnome-tweaks
      gnome.gnome-terminal
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
      # gnomeExtensions.simple-monitor # TODO: try this out
    ];
  };
}
