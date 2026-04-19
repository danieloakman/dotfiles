{ config, pkgs, lib, ... }:
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
      type = lib.types.attrsOf (lib.types.submodule {
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
      });
      default = { };
      description = "Services to display in Homepage";
    };
  };

  config = lib.mkIf config.my.services.homepage.enable ({
    networking.firewall.allowedTCPPorts = [ cfg.port ];

    services = {
      homepage-dashboard = {
        enable = true;
        allowedHosts = cfg.allowedHosts;
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
          # {
          #   search = {
          #     provider = "google";
          #     target = "_blank";
          #   };
          # }
          # {
          #   adguard = {
          #     url = "mara.dinosaur-crocodile.ts.net";
          #     username = "dano";
          #     password = "";
          #   };
          # }
        ];
        services = [{
          Services = lib.mapAttrsToList (name: service: { ${name} = service; }) cfg.services;
        }];
      };
    };

    environment.systemPackages = with pkgs; [
      (writeShellScriptBin "tailscale-svc-homepage-up" ''
        tailscale serve --service=svc:homepage --https=443 127.0.0.1:${toString cfg.port}
      '')
      (writeShellScriptBin "tailscale-svc-homepage-down" ''
        tailscale serve clear svc:homepage
      '')
    ];
  });
}
