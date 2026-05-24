{ config
, pkgs
, lib
, ...
}:
let
  cfg = config.my.services.homepage;
in
{
  options.my.services.homepage = {
    enable = lib.mkEnableOption "Enable the Homepage service";
    port = lib.mkOption {
      type = lib.types.int;
      default = 9092;
    };
    allowedHosts = lib.mkOption {
      type = lib.types.str;
      description = "Comma separated list of hosts that are allowed to access Homepage";
    };
    services = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            description = lib.mkOption {
              type = lib.types.str;
              description = "Description of the widget";
            };
            href = lib.mkOption {
              type = lib.types.str;
              description = "URL to redirect to when the widget is clicked";
            };
          };
        }
      );
      default = { };
      description = "Services to display in Homepage";
    };
  };

  config = lib.mkIf config.my.services.homepage.enable {
    networking.firewall.allowedTCPPorts = [ cfg.port ];

    services = {
      homepage-dashboard = {
        enable = true;
        inherit (cfg) allowedHosts;
        openFirewall = true;
        listenPort = cfg.port;
        widgets = [
          {
            resources = {
              cpu = true;
              disk = [
                "/"
                # TODO: move this to an option
                "/run/media/HDD_1"
              ];
              memory = true;
              units = "metric";
              cputemp = true;
              expanded = true;
            };
          }
        ];
        services = [
          {
            Services =
              (lib.mapAttrsToList (name: service: { ${name} = service; }) cfg.services)
              ++ lib.optionals config.services.adguardhome.enable [
                {
                  AdGuard = {
                    description = "Network-wide ad blocking DNS";
                    href = "http://mara";
                    widget = {
                      type = "adguard";
                      url = "http://127.0.0.1";
                      username = "{{HOMEPAGE_FILE_ADGUARD_USERNAME}}";
                      password = "{{HOMEPAGE_FILE_ADGUARD_PASSWORD}}";
                      fields = [
                        "queries"
                        "blocked"
                        "filtered"
                      ];
                    };
                  };
                }
              ]
              ++ lib.optionals config.services.jellyfin.enable [
                {
                  Jellyfin = {
                    description = "Media server";
                    href = "https://jellyfin.dinosaur-crocodile.ts.net";
                    widget = {
                      type = "jellyfin";
                      url = "http://127.0.0.1:8096";
                      key = "{{HOMEPAGE_FILE_JELLYFIN_API_KEY}}";
                      # Jellyfin >= 10.12 requires widget API version 2.
                      version = 2;
                      enableBlocks = true; # optional, defaults to false
                      enableNowPlaying = true; # optional, defaults to true
                      enableUser = true; # optional, defaults to false
                      enableMediaControl = true; # optional, defaults to true
                      showEpisodeNumber = true; # optional, defaults to false
                      expandOneStreamToTwoRows = true; # optional, defaults to true
                    };
                  };
                }
              ]
              ++ lib.optionals config.services.paperless.enable [
                {
                  Paperless = {
                    description = "Document management";
                    href = "https://paperless.dinosaur-crocodile.ts.net";
                    widget = {
                      type = "paperlessngx";
                      url = "http://127.0.0.1:${toString config.services.paperless.port}";
                      username = "{{HOMEPAGE_FILE_PAPERLESS_USERNAME}}";
                      password = "{{HOMEPAGE_FILE_PAPERLESS_PASSWORD}}";
                      fields = [
                        "total"
                        "inbox"
                      ];
                    };
                  };
                }
              ]
              ++ lib.optionals config.services.immich.enable [
                {
                  Immich = {
                    description = "Photo and video management";
                    href = "https://immich.dinosaur-crocodile.ts.net";
                  };
                  widget = {
                    type = "immich";
                    url = "http://127.0.0.1:${toString config.services.immich.port}";
                    key = "{{HOMEPAGE_FILE_IMMICH_API_KEY}}";
                    fields = [
                      "users"
                      "photos"
                      "videos"
                      "storage"
                    ];
                  };
                }
              ];
          }
        ];
      };
    };

    systemd.services.homepage-dashboard.environment = {
      HOMEPAGE_FILE_ADGUARD_USERNAME = config.sops.secrets.adguard_username.path;
      HOMEPAGE_FILE_ADGUARD_PASSWORD = config.sops.secrets.adguard_pwd.path;
      HOMEPAGE_FILE_JELLYFIN_API_KEY = config.sops.secrets.jellyfin_api_key.path;
      HOMEPAGE_FILE_PAPERLESS_USERNAME = config.sops.secrets.paperless_username.path;
      HOMEPAGE_FILE_PAPERLESS_PASSWORD = config.sops.secrets.paperless_pwd.path;
      HOMEPAGE_FILE_IMMICH_API_KEY = config.sops.secrets.immich_api_key.path;
    };
    systemd.services.homepage-dashboard.serviceConfig.SupplementaryGroups = [ "secrets" ];

    environment.systemPackages = with pkgs; [
      (writeShellScriptBin "tailscale-svc-homepage-up" ''
        tailscale serve --service=svc:homepage --https=443 127.0.0.1:${toString cfg.port}
      '')
      (writeShellScriptBin "tailscale-svc-homepage-down" ''
        tailscale serve clear svc:homepage
      '')
    ];
  };
}
