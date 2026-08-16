{ config, lib, pkgs, env, ... }:
let
  cfg = config.my.services.tailscale;
  serveCfg = config.services.tailscale.serve;
  ts = lib.getExe config.services.tailscale.package;

  # `tailscale serve set-config` cannot express frontend TLS termination
  # (tailscale#18381 / nixpkgs#530174): `tcp:443` → `http://…` becomes HTTP,
  # not HTTPS. Apply declared services with the CLI `--https` flag instead.
  serveApplyScript =
    let
      lines = lib.concatLists (
        lib.mapAttrsToList (
          name: svc:
          lib.mapAttrsToList (
            endpoint: target:
            let
              port = lib.removePrefix "tcp:" endpoint;
            in
            assert lib.hasPrefix "tcp:" endpoint;
            ''
              ${ts} serve clear ${lib.escapeShellArg "svc:${name}"} >/dev/null 2>&1 || true
              ${ts} serve --bg --service=${lib.escapeShellArg "svc:${name}"} --https=${port} ${lib.escapeShellArg target}
              ${lib.optionalString (svc.advertised == false) ''
                ${ts} serve drain ${lib.escapeShellArg "svc:${name}"} || true
              ''}
            ''
          ) svc.endpoints
        ) serveCfg.services
      );
    in
    pkgs.writeShellScript "tailscale-serve-https-apply" ''
      set -euo pipefail
      ${lib.concatStringsSep "\n" lines}
    '';
in
{
  options.my.services.tailscale = {
    enable-as-exit-node = lib.mkEnableOption "Enable this device as an exit node through Tailscale.";
    use-routing-features = lib.mkOption {
      type = lib.types.enum [ "none" "server" "client" "both" ];
      default = "none";
      description = "The routing features to use for Tailscale. See: https://search.nixos.org/options?channel=unstable&include_modular_service_options=1&include_nixos_options=1&query=tailscale+userouting&show=option:services.tailscale.useRoutingFeatures";
    };
  };

  config = env.selectPlatform {
    linux = {
      services.tailscale = {
        enable = true;
        extraSetFlags = lib.mkMerge [
          [
            "--operator=${env.user}"
            "--accept-routes=true"
            "--shields-up=false"
            "--ssh" # Always allow SSH access through Tailscale.
          ]
          (lib.mkIf cfg.enable-as-exit-node [
            "--advertise-exit-node"
            "--exit-node-allow-lan-access"
          ])
        ];
        # Other flags that can't be put in `extraSetFlags`:
        extraUpFlags = [
          "--advertise-tags=\"tag:${if env.deviceType == "server" then "server" else "client"}\""
        ];
        useRoutingFeatures = cfg.use-routing-features;
        openFirewall = true;
        serve.enable =
          lib.mkDefault (serveCfg.services != { });
      };

      # Replace stock `set-config --all` with HTTPS-capable CLI applies.
      systemd.services.tailscale-serve = lib.mkIf serveCfg.enable {
        serviceConfig.ExecStart = lib.mkForce serveApplyScript;
        restartTriggers = lib.mkForce [ serveApplyScript ];
      };

      # Open the DNS ports in the firewall for tailscale.
      networking.firewall = {
        trustedInterfaces = [ "tailscale0" ]; # Allow traffic from the tailscale interface to be forwarded to the local network.
      };

      home-manager.users.${env.user} = {
        # Starts the tailscale-systray, which is a tray icon for tailscale.
        services.tailscale-systray.enable = env.deviceType != "server"; # Only for non-server devices.
      };
    };

    darwin = {
      homebrew.casks = [ "tailscale-app" ];
    };
  };
}
