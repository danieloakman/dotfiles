{ config, lib, ... }:
let
  cfg = config.my.services.uptime-kuma;
  portStr = toString cfg.port;
in
{
  options.my.services.uptime-kuma = {
    enable = lib.mkEnableOption "Enable Uptime Kuma status monitoring";
    port = lib.mkOption {
      type = lib.types.port;
      default = 3001;
    };
    status-page-slug = lib.mkOption {
      type = lib.types.str;
      default = "homelab";
      description = "Uptime Kuma status page slug for the Homepage widget; empty disables the widget";
    };
  };

  config = lib.mkIf cfg.enable {
    services.uptime-kuma = {
      enable = true;
      settings = {
        HOST = "127.0.0.1";
        PORT = portStr;
      };
    };

    services.tailscale.serve.services.uptime-kuma = {
      endpoints."tcp:443" = "http://127.0.0.1:${portStr}";
    };

    my.services.homepage.services."Uptime Kuma" = {
      description = "Service uptime monitoring";
      href = "https://uptime-kuma.dinosaur-crocodile.ts.net";
      group = "Monitoring";
      icon = "uptime-kuma.png";
      widget =
        if cfg.status-page-slug == "" then
          null
        else
          {
            type = "uptimekuma";
            url = "http://127.0.0.1:${portStr}";
            slug = cfg.status-page-slug;
            fields = [
              "up"
              "down"
              "uptime"
            ];
          };
    };
  };
}
