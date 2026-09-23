{ lib, config, ... }:
let
  cfg = config.my.services.dns-ad-block;
in
{
  options.my.services.dns-ad-block = {
    enable = lib.mkEnableOption "Enable the DNS AdBlock service";
    port = lib.mkOption {
      type = lib.types.int;
      default = 2899;
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ cfg.port ];

    services.adguardhome = {
      enable = true;
      openFirewall = true;
      inherit (cfg) port;
    };

    my.services.homepage.services."AdGuard" = {
      description = "Network-wide ad blocking DNS";
      href = "http://${config.networking.hostName}";
      group = "Network";
      icon = "adguard-home.png";
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
  };
}
