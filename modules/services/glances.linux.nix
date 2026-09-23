{ config, lib, ... }:
let
  cfg = config.my.services.glances;
  portStr = toString cfg.port;
in
{
  options.my.services.glances = {
    enable = lib.mkEnableOption "Enable Glances web metrics (Homepage info widget when Homepage is on)";
    port = lib.mkOption {
      type = lib.types.port;
      default = 61208;
    };
  };

  config = lib.mkIf cfg.enable {
    services.glances = {
      enable = true;
      inherit (cfg) port;
      openFirewall = false;
      extraArgs = [
        "--webserver"
        "-B"
        "127.0.0.1"
      ];
    };

    services.tailscale.serve.services.glances = {
      endpoints."tcp:443" = "http://127.0.0.1:${portStr}";
    };

    my.services.homepage.services."Glances" = {
      description = "Host metrics (Glances)";
      href = "https://glances.dinosaur-crocodile.ts.net";
      group = "Monitoring";
      icon = "glances.png";
    };
  };
}
