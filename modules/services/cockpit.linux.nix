{ pkgs, lib, config, ... }:
let
  cfg = config.my.services.cockpit;
in
{
  options.my.services.cockpit = {
    enable = lib.mkEnableOption "Enable the Cockpit service";
    port = lib.mkOption {
      type = lib.types.int;
      default = 19090;
    };
    allowedOrigins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = cfg.allowedOrigins != [ ];
      message = "allowedOrigins must be a non-empty list";
    }];

    services = {
      cockpit = {
        enable = true;
        openFirewall = true;
        allowed-origins = cfg.allowedOrigins;
      };
    };

    environment.systemPackages = with pkgs; [
      # TODO: `mara-cockpit` service name is actually defined in tailscale console, not here. So eventually we need to rename that to something more generic, then we can edit this:
      (writeShellScriptBin "tailscale-svc-cockpit-up" ''
        tailscale serve --service=svc:mara-cockpit --https=443 127.0.0.1:${toString cfg.port}
      '')
      (writeShellScriptBin "tailscale-svc-cockpit-down" ''
        tailscale serve clear svc:mara-cockpit
      '')
    ];

    my.services.homepage.services."Cockpit" = {
      description = "System management";
      href = "http://mara-cockpit.dinosaur-crocodile.ts.net";
    };
  };
}
