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
  };
}
