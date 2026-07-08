{ pkgs, lib, config, ... }:
let
  cfg = config.my.services.cockpit;

  # Cockpit needs matching wss:// entries for every https:// origin when TLS is
  # terminated by Tailscale serve (see cockpit-project.org proxying docs).
  originsWithWebSockets =
    origins:
    let
      httpsOrigins = lib.filter (o: lib.hasPrefix "https://" o) origins;
      wssOrigins = map (o: lib.replaceStrings [ "https://" ] [ "wss://" ] o) httpsOrigins;
    in
    lib.unique (origins ++ wssOrigins);

  # Prefer a Tailscale MagicDNS origin for homepage links (must be https://).
  publicHref =
    lib.findFirst (o: lib.hasInfix ".ts.net" o) null cfg.allowedOrigins
      or "https://127.0.0.1:${toString cfg.port}";
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
      description = ''
        HTTPS origins allowed to proxy Cockpit (for example Tailscale serve hostnames).
        Matching `wss://` origins are added automatically for WebSocket sessions.
      '';
    };
    tailscaleService = lib.mkOption {
      type = lib.types.str;
      default = "mara-cockpit";
      description = ''
        Tailscale Service name (without the `svc:` prefix) used by
        `tailscale-svc-cockpit-up`. Must match the service defined in the admin console.
      '';
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
        inherit (cfg) port;
        # Expose via `tailscale-svc-cockpit-up` (127.0.0.1 backend).
        openFirewall = false;
        allowed-origins = originsWithWebSockets cfg.allowedOrigins;
        settings.WebService.ProtocolHeader = "X-Forwarded-Proto";
      };
    };

    environment.systemPackages = with pkgs; [
      (writeShellScriptBin "tailscale-svc-cockpit-up" ''
        tailscale serve --service=svc:${cfg.tailscaleService} --https=443 http://127.0.0.1:${toString cfg.port}
      '')
      (writeShellScriptBin "tailscale-svc-cockpit-down" ''
        tailscale serve clear svc:${cfg.tailscaleService}
      '')
    ];

    my.services.homepage.services."Cockpit" = {
      description = "System management";
      href = publicHref;
    };
  };
}
