{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.streaming;
  jellyfinPort = 8096;
  # sonarrPort = 8989;
  # radarrPort = 7878;
  # bazarrPort = 6767;
  # transmissionPort = 9091;
  # prowlarrPort = 9696;
  # flaresolverrPort = 8191;

  # X-Emby-Token / ?api_key= return 401 on this deploy; MediaBrowser Token works.
  jellyfinScan = pkgs.writeShellApplication {
    name = "jellyfin-scan";
    runtimeInputs = [ pkgs.curl pkgs.coreutils ];
    text = ''
      set -euo pipefail
      key_file=/run/secrets/jellyfin_api_key
      if [[ ! -r "$key_file" ]]; then
        echo "error: cannot read $key_file (need root / sops secret)" >&2
        exit 1
      fi
      key=$(tr -d '\n' <"$key_file")
      code=$(curl -sS -o /dev/null -w '%{http_code}' -X POST \
        -H "Authorization: MediaBrowser Token=\"$key\"" \
        "http://127.0.0.1:${toString jellyfinPort}/Library/Refresh")
      if [[ "$code" != "204" && "$code" != "200" ]]; then
        echo "error: Library/Refresh returned HTTP $code" >&2
        exit 1
      fi
      echo "jellyfin library refresh requested (HTTP $code)"
    '';
  };
in
{
  options.my.services.streaming = {
    jellyfin = {
      enable = lib.mkEnableOption "Enable the Jellyfin service";
    };
  };

  config = {
    environment.systemPackages = lib.mkIf cfg.jellyfin.enable [ jellyfinScan ];

    services.tailscale.serve.services.jellyfin = lib.mkIf cfg.jellyfin.enable {
      endpoints."tcp:443" = "http://127.0.0.1:${toString jellyfinPort}";
    };
    my.services.homepage.services."Jellyfin" = lib.mkIf cfg.jellyfin.enable {
      description = "Media server";
      href = "https://jellyfin.dinosaur-crocodile.ts.net";
      group = "Media";
      icon = "jellyfin.png";
      widget = {
        type = "jellyfin";
        url = "http://127.0.0.1:${toString jellyfinPort}";
        key = "{{HOMEPAGE_FILE_JELLYFIN_API_KEY}}";
        # Jellyfin >= 10.12 requires widget API version 2.
        version = 2;
        enableBlocks = true;
        enableNowPlaying = true;
        enableUser = true;
        enableMediaControl = true;
        showEpisodeNumber = true;
        expandOneStreamToTwoRows = true;
      };
    };
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
        # Expose via services.tailscale.serve (127.0.0.1 backend).
        openFirewall = false;
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
      #   #   download-dir = "/run/media/HDD_3/Downloads";
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
