{ env, pkgs, ... }:
let
  user = "immich";
  group = "immich";
  port = 2283;
in
{

  services = {
    immich = {
      inherit user group port;
      host = "0.0.0.0"; # Open to all interfaces
      enable = true;
      openFirewall = true;
      accelerationDevices = null;
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
      tailscale serve --service=svc:immich --https=443 0.0.0.0:${toString port}
    '')
    (writeShellScriptBin "tailscale-svc-immich-down" ''
      tailscale serve clear svc:immich
    '')
  ];

  networking.firewall = {
    allowedTCPPorts = [ port ];
    allowedUDPPorts = [ port ];
  };

  home-manager.users.${env.user} = {
    xdg.desktopEntries =
      let
        webapp = url: "uwsm app -- vivaldi --ozone-platform=wayland --app=\"${url}\"";
      in
      {
        immich-webapp = {
          name = "Immich Webapp";
          exec = webapp "http://localhost:${toString port}";
          categories = [ "Network" "WebBrowser" ];
          icon = "immich";
          startupNotify = true;
        };
      };
  };
}
