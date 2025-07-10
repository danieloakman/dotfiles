# Gnome configuration

{ pkgs, config, ... }:
{
  imports = [
    # Was having problems with uluancher and setting the activation key to NOT be ctrl + space. I want it to be super + space. But it's not working.
    # It's not even that useful, compared to raycast. Maybe I'll try out rofi instead.
    # ./ulauncher.nix
    # Not using anymore. I just prefer to use gmail in the browser:
    # ./evolution.nix
    ./keybinds.nix
  ];

  services = {
    # Enable the GNOME Desktop Environment.
    displayManager = {
      gdm.enable = true;
      # autoLogin = {
      #   enable = true;
      #   user = env.user;
      # };
    };
    desktopManager.gnome.enable = true;

    gnome.games.enable = false; # Disable all games
  };

  environment = {
    # Exclude particular gnome specific packages
    gnome.excludePackages = with pkgs; [
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
      gnome-music
      gnome-characters
      tali # poker game
      iagno # go game
      hitori # sudoku game
      atomix # puzzle game
      gnome-contacts
      gnome-initial-setup
      gnome-maps
      gnome-weather
    ];

    systemPackages = with pkgs; [
      networkmanager
      networkmanagerapplet # Provides `nmi-connection-editor` command
      networkmanager-openvpn
      gnome-tweaks
      gnome-terminal
      # gnome.pomodoro # Not updated
      # gnome.cheese # Web cam tool
      gnomeExtensions.appindicator
      gnomeExtensions.tailscale-qs
      gnome-frog # OCR tool
      # gnomeExtensions.touch-x Not updated
      gnomeExtensions.system-monitor-next # "System Monitor" is better for now
      gnomeExtensions.syncthing-indicator
      gnomeExtensions.gsconnect
      # The following all didn't work on nixos or was not compatible with gnome v45
      # gnomeExtensions.valent
      # gnomeExtensions.enhanced-osk # TODO: remove this comment if gjs-osk is good
      # gnomeExtensions.gjs-osk
      gnomeExtensions.docker
    ];
  };

  networking.firewall = {
    # Open required ports for gsconnect:
    allowedTCPPortRanges = [{ from = 1716; to = 1764; }];
    allowedUDPPortRanges = [{ from = 1716; to = 1764; }];
  };

  home-manager.users.${config.env.user} = {
    services.gnome-keyring.enable = true;
  };
}
