{ env, pkgs, lib, config, ... }:
let
  user = "immich";
  group = "immich";
  cfg = config.my.services.immich;
  goCfg = cfg.immich-go;

  # --server and --api-key belong to `upload` and `stack`, not the root command.
  # Insert them after that word so `version`, `help`, and `archive` pass through.
  # A later --server or --api-key on the command line overrides these.
  wrappedImmichGo = pkgs.writeShellScriptBin "immich-go" ''
    set -euo pipefail
    key_file=${lib.escapeShellArg goCfg.api-key}
    server=${lib.escapeShellArg goCfg.server}
    bin=${lib.getExe pkgs.immich-go}

    read_api_key() {
      if [[ ! -r $key_file ]]; then
        echo "immich-go: cannot read API key file $key_file" >&2
        exit 1
      fi
      local key
      key=$(tr -d '\r\n' < "$key_file")
      if [[ -z $key ]]; then
        echo "immich-go: API key file $key_file is empty" >&2
        exit 1
      fi
      printf '%s' "$key"
    }

    prefix=()
    while [[ $# -gt 0 ]]; do
      case "$1" in
        upload|stack)
          exec "$bin" "''${prefix[@]}" "$1" \
            --server "$server" \
            --api-key "$(read_api_key)" \
            "''${@:2}"
          ;;
        --concurrent-tasks|--config|--log-file|--log-level|--log-type|--on-errors|-l)
          if [[ $# -lt 2 ]]; then
            break
          fi
          prefix+=("$1" "$2")
          shift 2
          ;;
        -*)
          prefix+=("$1")
          shift
          ;;
        *)
          break
          ;;
      esac
    done

    exec "$bin" "''${prefix[@]}" "$@"
  '';
in
{
  options.my.services.immich = {
    enable = lib.mkEnableOption "Enable the Immich service";
    port = lib.mkOption {
      type = lib.types.int;
      default = 2283;
    };
    media-location = lib.mkOption {
      type = lib.types.str;
      description = "The location of the media files for Immich";
    };
    immich-go = {
      enable = lib.mkEnableOption "Install immich-go, the Immich bulk-upload CLI";
      api-key = lib.mkOption {
        type = lib.types.str;
        default = config.sops.secrets.immich_api_key.path;
        defaultText = lib.literalExpression "config.sops.secrets.immich_api_key.path";
        description = ''
          Runtime path of a file containing the Immich API key.
          The wrapper reads it when running `upload` or `stack`.
          Defaults to the immich_api_key sops secret and is not copied into the Nix store.
        '';
      };
      server = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:${toString config.my.services.immich.port}";
        defaultText = lib.literalExpression ''"http://127.0.0.1:''${config.my.services.immich.port}"'';
        example = "https://immich.dinosaur-crocodile.ts.net";
        description = ''
          Immich base URL passed as `--server`.
          Defaults to the local service address from `my.services.immich.port`.
        '';
      };
    };
  };

  # immich-go is a client. It does not require the local Immich server.
  config = lib.mkMerge [
    (lib.mkIf goCfg.enable {
      environment.systemPackages = [ wrappedImmichGo ];
    })
    (lib.mkIf cfg.enable {
      assertions = [{
        assertion = cfg.media-location != null;
        message = "immich.media-location must be set";
      }];

      services = {
        immich = {
          inherit user group;
          inherit (cfg) port;
          # Bind to loopback and expose to tailnet via tailscale serve.
          host = "127.0.0.1";
          enable = true;
          openFirewall = false;
          accelerationDevices = null;
          mediaLocation = cfg.media-location;
        };
      };

      users.users = {
        ${user} = {
          extraGroups = [ "video" "render" ];
        };
        ${env.user} = {
          extraGroups = [ group "video" "render" ];
        };
      };

      environment.systemPackages = [ pkgs.immich-cli ];

      services.tailscale.serve.services.immich = {
        endpoints."tcp:443" = "http://127.0.0.1:${toString cfg.port}";
      };

      networking.firewall = {
        allowedTCPPorts = [ cfg.port ];
        allowedUDPPorts = [ cfg.port ];
      };

      my.programs.webapps = {
        "Immich" = {
          url = "http://localhost:${toString cfg.port}";
          icon = "folder-pictures";
        };
      };

      my.services.homepage.services."Immich" = {
        description = "Photo and video management";
        href = "https://immich.dinosaur-crocodile.ts.net";
        group = "Media";
        icon = "immich.png";
        widget = {
          type = "immich";
          url = "http://127.0.0.1:${toString cfg.port}";
          key = "{{HOMEPAGE_FILE_IMMICH_API_KEY}}";
          version = 2;
          fields = [
            "users"
            "photos"
            "videos"
            "storage"
          ];
        };
      };
    })
  ];
}
