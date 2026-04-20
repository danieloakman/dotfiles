{ config, lib, env, ... }:
let
  cfg = config.my.services.tailscale;
in
{
  options.my.services.tailscale = {
    enableAsExitNode = lib.mkEnableOption "Enable this device as an exit node through Tailscale.";
    useRoutingFeatures = lib.mkOption {
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
          ([
            "--operator=${env.user}"
            "--accept-routes=true"
            "--shields-up=false"
            "--ssh" # Always allow SSH access through Tailscale.
          ])
          (lib.mkIf cfg.enableAsExitNode [
            "--advertise-exit-node"
            "--exit-node-allow-lan-access"
          ])
        ];
        # Other flags that can't be put in `extraSetFlags`:
        extraUpFlags = [
          "--advertise-tags=\"tag:${if env.deviceType == "server" then "server" else "client"}\""
        ];
        useRoutingFeatures = cfg.useRoutingFeatures;
        openFirewall = true;
        # Enables the Tailscale Serve configs:
        # For some reason, this doesn't work at the moment. So I'm just going to add enable and disable scripts for each service.
        serve.enable = false;
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
