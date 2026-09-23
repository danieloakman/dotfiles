{ config
, lib
, ...
}:
let
  cfg = config.my.services.homepage;
  glancesCfg = config.my.services.glances;

  serviceEntry = name: service:
    {
      ${name} =
        {
          inherit (service) description href;
        }
        // lib.optionalAttrs (service.icon != null) { inherit (service) icon; }
        // lib.optionalAttrs (service.widget != null) { inherit (service) widget; };
    };

  groupedServices =
    let
      byGroup = lib.foldlAttrs
        (
          acc: name: service:
          let
            g = service.group;
          in
          acc
          // {
            ${g} = (acc.${g} or [ ]) ++ [ (serviceEntry name service) ];
          }
        )
        { }
        cfg.services;
      ordered =
        map (g: { ${g} = byGroup.${g}; }) (lib.filter (g: byGroup ? ${g}) cfg.group-order);
      restGroups = lib.subtractLists cfg.group-order (lib.attrNames byGroup);
      rest = map (g: { ${g} = byGroup.${g}; }) (lib.sort (a: b: a < b) restGroups);
    in
    ordered ++ rest;

  infoWidgets =
    lib.optionals cfg.widgets.datetime.enable [
      {
        datetime = {
          text_size = "xl";
          format = {
            timeStyle = "short";
            dateStyle = "medium";
            hourCycle = "h23";
          };
          locale = "en-AU";
        };
      }
    ]
    ++ lib.optionals cfg.widgets.openmeteo.enable [
      {
        openmeteo = {
          units = "metric";
          cache = 5;
        };
      }
    ]
    ++ lib.optionals cfg.widgets.search.enable [
      {
        search = {
          provider = cfg.widgets.search.provider;
          target = "_blank";
        };
      }
    ]
    ++ (
      if glancesCfg.enable then
        [
          {
            glances = {
              url = "http://127.0.0.1:${toString glancesCfg.port}";
              version = 4;
              cpu = true;
              mem = true;
              cputemp = true;
              uptime = true;
              disk = cfg.disks;
              expanded = true;
              label = config.networking.hostName;
            };
          }
        ]
      else
        [
          {
            resources = {
              cpu = true;
              disk = cfg.disks;
              memory = true;
              units = "metric";
              cputemp = true;
              expanded = true;
            };
          }
        ]
    );

  defaultBookmarks = [
    {
      Links = [
        {
          GitHub = [
            {
              abbr = "GH";
              href = "https://github.com/";
            }
          ];
        }
        {
          Tailscale = [
            {
              abbr = "TS";
              href = "https://login.tailscale.com/admin/machines";
            }
          ];
        }
        {
          "NixOS Search" = [
            {
              abbr = "NS";
              href = "https://search.nixos.org/packages";
            }
          ];
        }
      ];
    }
  ];
in
{
  options.my.services.homepage = {
    enable = lib.mkEnableOption "Enable the Homepage service";
    port = lib.mkOption {
      type = lib.types.int;
      default = 9092;
    };
    allowed-hosts = lib.mkOption {
      type = lib.types.str;
      description = "Comma separated list of hosts that are allowed to access Homepage";
    };
    disks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "/"
        "/run/media/HDD_1"
      ];
      description = "Mount points shown in the resources or Glances widget";
    };
    group-order = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "Media"
        "Documents"
        "Network"
        "AI"
        "Files"
        "Admin"
        "Monitoring"
      ];
      description = "Order of service groups on the dashboard; unlisted groups append alphabetically";
    };
    widgets = {
      datetime.enable = lib.mkEnableOption "Show the datetime info widget" // {
        default = true;
      };
      openmeteo.enable = lib.mkEnableOption "Show the Open-Meteo weather widget (browser geolocation)" // {
        default = true;
      };
      search = {
        enable = lib.mkEnableOption "Show the search info widget" // {
          default = true;
        };
        provider = lib.mkOption {
          type = lib.types.str;
          default = "duckduckgo";
          description = "Homepage search provider id";
        };
      };
    };
    bookmarks = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      default = defaultBookmarks;
      description = "Homepage bookmarks (same shape as services.homepage-dashboard.bookmarks)";
    };
    integrations.tailscale = {
      enable = lib.mkEnableOption "Show a Tailscale machine status tile (needs tailscale_api_key secret)";
      device-id = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Tailscale machine ID (ends with CNTRL)";
      };
    };
    services = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            description = lib.mkOption {
              type = lib.types.str;
              description = "Description of the service tile";
            };
            href = lib.mkOption {
              type = lib.types.str;
              description = "URL to open when the tile is clicked";
            };
            group = lib.mkOption {
              type = lib.types.str;
              default = "Services";
              description = "Dashboard group heading for this tile";
            };
            icon = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Homepage icon name (mdi-… or built-in)";
            };
            widget = lib.mkOption {
              type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
              default = null;
              description = "Freeform Homepage service widget config";
            };
          };
        }
      );
      default = { };
      description = "Services to display in Homepage";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion =
          !cfg.integrations.tailscale.enable || cfg.integrations.tailscale.device-id != "";
        message = "my.services.homepage.integrations.tailscale.device-id must be set when enable is true";
      }
    ];

    services.homepage-dashboard = {
      enable = true;
      allowedHosts = cfg.allowed-hosts;
      # Loopback-only; expose via services.tailscale.serve.
      openFirewall = false;
      listenPort = cfg.port;
      inherit (cfg) bookmarks;
      widgets = infoWidgets;
      services = groupedServices;
      settings = {
        title = config.networking.hostName;
        quicklaunch = {
          searchDescriptions = true;
          hideInternetSearch = false;
          showSearchSuggestions = true;
          provider = cfg.widgets.search.provider;
        };
      };
    };

    my.services.homepage.services = lib.mkIf cfg.integrations.tailscale.enable {
      Tailscale = {
        description = "Tailscale machine status";
        href = "https://login.tailscale.com/admin/machines";
        group = "Network";
        icon = "tailscale.png";
        widget = {
          type = "tailscale";
          deviceid = cfg.integrations.tailscale.device-id;
          key = "{{HOMEPAGE_FILE_TAILSCALE_API_KEY}}";
          fields = [
            "address"
            "last_seen"
            "hostname"
            "os"
            "update_available"
          ];
        };
      };
    };

    systemd.services.homepage-dashboard.environment = {
      HOMEPAGE_FILE_ADGUARD_USERNAME = config.sops.secrets.adguard_username.path;
      HOMEPAGE_FILE_ADGUARD_PASSWORD = config.sops.secrets.adguard_pwd.path;
      HOMEPAGE_FILE_JELLYFIN_API_KEY = config.sops.secrets.jellyfin_api_key.path;
      HOMEPAGE_FILE_PAPERLESS_USERNAME = config.sops.secrets.paperless_username.path;
      HOMEPAGE_FILE_PAPERLESS_PASSWORD = config.sops.secrets.paperless_pwd.path;
      HOMEPAGE_FILE_IMMICH_API_KEY = config.sops.secrets.immich_api_key.path;
      HOMEPAGE_FILE_TAILSCALE_API_KEY = config.sops.secrets.tailscale_api_key.path;
      HOMEPAGE_FILE_SPEEDTEST_API_KEY = config.sops.secrets.speedtest_tracker_api_key.path;
    };
    systemd.services.homepage-dashboard.serviceConfig.SupplementaryGroups = [ "secrets" ];

    services.tailscale.serve.services.homepage = {
      endpoints."tcp:443" = "http://127.0.0.1:${toString cfg.port}";
    };
  };
}
