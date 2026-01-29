{ config, env, pkgs, ... }:
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

    # tailscale.serve.services = {
    #   "immich" = {
    #     endpoints = {
    #       "tcp:${toString port}" = "http://localhost:${toString port}";
    #     };
    #     advertised = true;
    #   };
    # };
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
