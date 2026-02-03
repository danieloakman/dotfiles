{ config, pkgs, ... }:
let
  port = 9092;
  host = config.networking.hostName;
in
{
  networking.firewall.allowedTCPPorts = [ port ];

  services = {
    homepage-dashboard = {
      enable = true;
      allowedHosts = "${host}:${toString port},localhost:${toString port},homepage.dinosaur-crocodile.ts.net";
      openFirewall = true;
      listenPort = port;
      widgets = [
        {
          resources = {
            cpu = true;
            disk = [
              "/"
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
        "Services" = [
          {
            "Cockpit" = {
              description = "System management";
              # href = "http://mara-cockpit.dinosaur-crocodile.ts.net";
              href = "http://mara:9090";
            };
          }
          {
            "Immich" = {
              description = "Image hosting and management";
              href = "http://mara:2283";
            };
          }
          {
            "N8N" = {
              description = "Automation platform";
              href = "https://n8n.dinosaur-crocodile.ts.net";
            };
          }
          {
            "Stirling PDF" = {
              description = "PDF Utilities";
              href = "https://stirling-pdf.dinosaur-crocodile.ts.net";
            };
          }
          {
            "Jellyfin" = {
              description = "Media server";
              href = "https://jellyfin.dinosaur-crocodile.ts.net";
            };
          }
          {
            "Copyparty" = {
              description = "File sharing";
              href = "https://copyparty.dinosaur-crocodile.ts.net";
            };
          }
        ];
      }];
    };
  };

  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "tailscale-svc-homepage-up" ''
      tailscale serve --service=svc:homepage --https=443 127.0.0.1:${toString port}
    '')
    (writeShellScriptBin "tailscale-svc-homepage-down" ''
      tailscale serve clear svc:homepage
    '')
  ];
}
