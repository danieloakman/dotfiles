{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.postiz;
  publicBase = cfg.publicBaseUrl or "http://127.0.0.1:${toString cfg.port}";

  composeDir = pkgs.runCommand "postiz-compose" { } ''
    mkdir -p $out
    cp ${./docker-compose.yaml} $out/docker-compose.yaml
    cp -r ${./dynamicconfig} $out/dynamicconfig
  '';

  startScript = pkgs.writeShellScript "postiz-compose-up" ''
    set -euo pipefail
    export POSTIZ_JWT_SECRET="$(tr -d '\n' < ${lib.escapeShellArg cfg.jwtSecretFile})"
    export POSTIZ_MAIN_URL=${lib.escapeShellArg publicBase}
    export POSTIZ_FRONTEND_URL=${lib.escapeShellArg publicBase}
    export POSTIZ_NEXT_PUBLIC_BACKEND_URL=${lib.escapeShellArg "${publicBase}/api"}
    export POSTIZ_HTTP_PORT=${toString cfg.port}
    export POSTIZ_TEMPORAL_UI_PORT=${toString cfg.temporalUiPort}
    cd ${composeDir}
    exec ${lib.getExe pkgs.docker} compose up -d --remove-orphans
  '';

  stopScript = pkgs.writeShellScript "postiz-compose-down" ''
    set -euo pipefail
    cd ${composeDir}
    exec ${lib.getExe pkgs.docker} compose down
  '';
in
{
  options.my.services.postiz = {
    enable = lib.mkEnableOption "Postiz social scheduling stack (Docker Compose).";

    port = lib.mkOption {
      type = lib.types.port;
      default = 10322;
      description = "Host port mapped to Postiz (container port 5000).";
    };

    publicBaseUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Public origin for MAIN_URL, FRONTEND_URL, and NEXT_PUBLIC_BACKEND_URL (e.g. https://postiz.example.com).
        When null, defaults to http://127.0.0.1:<port>. Must match how users reach the UI (see Postiz docs).
      '';
    };

    jwtSecretFile = lib.mkOption {
      type = lib.types.str;
      description = ''
        File containing the JWT secret (single line). Use a sops-nix secret path such as
        config.sops.secrets.postiz_jwt_secret.path after defining that secret.
      '';
    };

    temporalUiPort = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Host port for Temporal Web UI.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open the main Postiz TCP port on the firewall.";
    };

    openTemporalUiInFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open temporalUiPort on the firewall.";
    };

    openSpotlightInFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open Sentry Spotlight (TCP 8969) on the firewall.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [
        {
          assertion = cfg.jwtSecretFile != "";
          message = "my.services.postiz.jwtSecretFile must be non-empty when Postiz is enabled.";
        }
      ];

      my.services.docker.enable = lib.mkDefault true;

      systemd.services.postiz-docker-compose = {
        description = "Postiz (official Docker Compose stack)";
        after = [
          "network-online.target"
          "docker.service"
        ];
        wants = [ "network-online.target" ];
        requires = [ "docker.service" ];
        wantedBy = [ "multi-user.target" ];
        path = [ pkgs.docker ];
        environment = {
          COMPOSE_PROJECT_NAME = "postiz";
        };
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          WorkingDirectory = composeDir;
            ExecStart = "${startScript}";
            ExecStop = "${stopScript}";
          TimeoutStartSec = 0;
        };
      };
    }
    (lib.mkIf cfg.openFirewall {
      networking.firewall.allowedTCPPorts = [ cfg.port ];
    })
    (lib.mkIf (cfg.openFirewall && cfg.openTemporalUiInFirewall) {
      networking.firewall.allowedTCPPorts = [ cfg.temporalUiPort ];
    })
    (lib.mkIf (cfg.openFirewall && cfg.openSpotlightInFirewall) {
      networking.firewall.allowedTCPPorts = [ 8969 ];
    })
  ]);
}
