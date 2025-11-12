{ lib, config, env, pkgs, ... }:
let
  jellyfinPort = 8096;
  # sonarrPort = 8989;
  # radarrPort = 7878;
  # bazarrPort = 6767;
  # transmissionPort = 9091;
  # prowlarrPort = 9696;
  # flaresolverrPort = 8191;
in
{
  options = {
    streaming.enable = lib.mkEnableOption "Enable streaming services";
  };

  config = lib.mkIf config.streaming.enable {
    environment.systemPackages = with pkgs; [
      qbittorrent
    ];

    services = {
      jellyfin = {
        enable = true;
        openFirewall = true;
      };
      # sonarr = {
      #   enable = true;
      #   openFirewall = true;
      #   settings.server.port = sonarrPort;
      # };
      # radarr = {
      #   enable = true;
      #   openFirewall = true;
      #   settings.server.port = radarrPort;
      # };
      # bazarr = {
      #   enable = true;
      #   openFirewall = true;
      #   listenPort = bazarrPort;
      # };
      # transmission = {
      #   enable = true;
      #   openFirewall = true;
      #   # settings = {
      #   #   downloadDir = "/run/media/HDD_3/Downloads";
      #   #   incompleteDir = "/run/media/HDD_3/Downloads/incomplete";
      #   # };
      #   # credentialsFile = config.sops.secrets.transmission_credentials.path;
      # };
      # prowlarr = {
      #   enable = true;
      #   openFirewall = true;
      #   settings.server.port = prowlarrPort;
      # };
      # flaresolverr = {
      #   enable = true;
      #   openFirewall = true;
      #   port = flaresolverrPort;
      # };
    };

    home-manager.users.${env.user} = {
      xdg.desktopEntries =
        let
          webapp = url: extraArgs: {
            exec = "uwsm app -- vivaldi --ozone-platform=wayland --app=\"${url}\"";
            categories = [ "Network" "WebBrowser" ];
            icon = "vivaldi";
            startupNotify = true;
          } // extraArgs;
        in
        {
          jellyfin-webapp = webapp "http://localhost:${toString jellyfinPort}" {
            name = "Jellyfin Webapp";
            comment = "For watching the content you download";
          };
          # sonarr-webapp = webapp "http://localhost:${toString sonarrPort}" {
          #   name = "Sonarr Webapp";
          #   comment = "*arr service for automatically downloading TV shows";
          # };
          # radarr-webapp = webapp "http://localhost:${toString radarrPort}" {
          #   name = "Radarr Webapp";
          #   comment = "*arr service for automatically downloading movies";
          # };
          # bazarr-webapp = webapp "http://localhost:${toString bazarrPort}" {
          #   name = "Bazarr Webapp";
          #   comment = "Automatically downloads subtitles for Sonarr and Radarr";
          # };
          # transmission-webapp = webapp "http://localhost:${toString transmissionPort}" {
          #   name = "Transmission Webapp";
          #   comment = "Download manager for torrents";
          # };
          # prowlarr-webapp = webapp "http://localhost:${toString prowlarrPort}" {
          #   name = "Prowlarr Webapp";
          #   comment = "Meta-indexer for automatically downloading TV shows and movies";
          # };
        };
    };
  };
}
