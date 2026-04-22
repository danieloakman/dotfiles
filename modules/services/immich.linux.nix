{ env, pkgs, lib, config, ... }:
let
  user = "immich";
  group = "immich";
  cfg = config.my.services.immich;
in
{
  options.my.services.immich = {
    enable = lib.mkEnableOption "Enable the Immich service";
    port = lib.mkOption {
      type = lib.types.int;
      default = 2283;
    };
    mediaLocation = lib.mkOption {
      type = lib.types.str;
      description = "The location of the media files for Immich";
    };
  };

  config = lib.mkIf config.my.services.immich.enable ({
    assertions = [{
      assertion = cfg.mediaLocation != null;
      message = "immich.mediaLocation must be set";
    }];

    services = {
      immich = {
        inherit user group;
        inherit (cfg) port;
        # Bind to loopback and expose to tailnet via tailscale serve.
        host = "127.0.0.1";
        enable = true;
        openFirewall = true;
        accelerationDevices = null;
        mediaLocation = cfg.mediaLocation;
      };
    };

    users.users = {
      ${user} = {
        extraGroups = [ "video" "render" ];
      };
      ${env.user} = {
        extraGroups = [ group "video" "render" ];
      };
    };

    environment.systemPackages = with pkgs; [
      immich-cli
      (writeShellScriptBin "tailscale-svc-immich-up" ''
        tailscale serve --service=svc:immich --https=443 127.0.0.1:${toString cfg.port}
      '')
      (writeShellScriptBin "tailscale-svc-immich-down" ''
        tailscale serve clear svc:immich
      '')
    ];

    networking.firewall = {
      allowedTCPPorts = [ cfg.port ];
      allowedUDPPorts = [ cfg.port ];
    };

    home-manager.users.${env.user} = {
      xdg.desktopEntries =
        let
          webapp = url: "uwsm app -- vivaldi --ozone-platform=wayland --app=\"${url}\"";
        in
        {
          immich-webapp = {
            name = "Immich Webapp";
            exec = webapp "http://localhost:${toString cfg.port}";
            categories = [ "Network" "WebBrowser" ];
            icon = "immich";
            startupNotify = true;
          };
        };
    };
  });
}
