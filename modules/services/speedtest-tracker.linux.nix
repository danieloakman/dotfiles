{ config, lib, ... }:
let
  cfg = config.my.services.speedtest-tracker;
  portStr = toString cfg.port;
  publicHost = "speedtest.dinosaur-crocodile.ts.net";
in
{
  options.my.services.speedtest-tracker = {
    enable = lib.mkEnableOption "Enable Speedtest Tracker (internet performance history)";
    port = lib.mkOption {
      type = lib.types.port;
      default = 8765;
      description = "Loopback nginx port; exposed via Tailscale serve";
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets.speedtest_tracker_app_key = {
      owner = lib.mkForce "speedtest-tracker";
      group = lib.mkForce "speedtest-tracker";
      mode = lib.mkForce "0440";
    };

    services.speedtest-tracker = {
      enable = true;
      enableNginx = true;
      virtualHost = publicHost;
      settings = {
        APP_KEY_FILE = config.sops.secrets.speedtest_tracker_app_key.path;
        APP_URL = "https://${publicHost}";
        DB_CONNECTION = "sqlite";
      };
    };

    # Loopback-only; Tailscale serve is the public edge.
    services.nginx.virtualHosts.${publicHost}.listen = [
      {
        addr = "127.0.0.1";
        port = cfg.port;
      }
    ];

    services.tailscale.serve.services.speedtest = {
      endpoints."tcp:443" = "http://127.0.0.1:${portStr}";
    };

    my.services.homepage.services."Speedtest Tracker" = {
      description = "WAN speed history";
      href = "https://${publicHost}";
      group = "Monitoring";
      icon = "speedtest-tracker.png";
      widget = {
        type = "speedtest";
        url = "http://127.0.0.1:${portStr}";
        version = 2;
        key = "{{HOMEPAGE_FILE_SPEEDTEST_API_KEY}}";
        fields = [
          "download"
          "upload"
          "ping"
        ];
      };
    };
  };
}
