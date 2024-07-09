# Gnome configuration

{ pkgs, ... }:
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
  services.gnome.games.enable = false; # Disable all games

  environment = {
    systemPackages = with pkgs; [
      # TODO: Probably move this stuff to system.nix:
      networkmanager
      networkmanagerapplet # Provides `nmi-connection-editor` command
      gnome.networkmanager-openvpn
      gnome.gnome-tweaks
      gnome.gnome-terminal
      gnome.pomodoro
      # gnome.cheese # Web cam tool
      gnomeExtensions.appindicator
      gnomeExtensions.tailscale-status
      gnome-frog # OCR tool
      gnomeExtensions.touch-x
      gnomeExtensions.system-monitor-next
      # The following all didn't work on nixos or was not compatible with gnome v45
      # gnomeExtensions.valent
      # gnomeExtensions.enhanced-osk # TODO: remove this comment if gjs-osk is good
      # gnomeExtensions.gjs-osk
      # gnomeExtensions.simple-monitor # TODO: try this out
    ];
  };
}
