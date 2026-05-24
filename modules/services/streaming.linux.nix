{ env, pkgs, config, lib, ... }:
let
  cfg = config.my.services.streaming;
  jellyfinPort = 8096;
  # sonarrPort = 8989;
  # radarrPort = 7878;
  # bazarrPort = 6767;
  # transmissionPort = 9091;
  # prowlarrPort = 9696;
  # flaresolverrPort = 8191;
in
{
  options.my.services.streaming = {
    jellyfin = {
      enable = lib.mkEnableOption "Enable the Jellyfin service";
    };
  };

  config = {
    environment.systemPackages = lib.optionals cfg.jellyfin.enable (with pkgs; [
      (writeShellScriptBin "tailscale-svc-jellyfin-up" ''
        tailscale serve --service=svc:jellyfin --https=443 127.0.0.1:${toString jellyfinPort}
      '')
      (writeShellScriptBin "tailscale-svc-jellyfin-down" ''
        tailscale serve clear svc:jellyfin
      '')
    ]);
    my.programs.webapps = {
      "Jellyfin" = lib.mkIf cfg.jellyfin.enable {
        url = "http://localhost:${toString jellyfinPort}";
        icon = "video";
        categories = [ "Network" "WebBrowser" ];
      };
      # TODO: Refactor below to use the same pattern as Jellyfin above.
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
    services = {
      jellyfin = lib.mkIf cfg.jellyfin.enable {
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
  };
}
