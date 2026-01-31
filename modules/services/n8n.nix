{ env, pkgs, ... }:
let
  port = 5678;
in
{
  services.n8n = {
    enable = true;
    openFirewall = true;
    environment.N8N_PORT = port;
  };

  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "tailscale-svc-n8n-up" ''
      tailscale serve --service=svc:n8n --https=443 127.0.0.1:${toString port}
    '')
    (writeShellScriptBin "tailscale-svc-n8n-down" ''
      tailscale serve clear svc:n8n
    '')
  ];

  home-manager.users.${env.user} = {
    xdg.desktopEntries =
      let
        webapp = url: "uwsm app -- vivaldi --ozone-platform=wayland --app=\"${url}\"";
      in
      {
        n8n = {
          name = "N8N Automation Platform";
          exec = webapp "http://localhost:${toString port}";
          categories = [ "Network" "WebBrowser" ];
          icon = "vivaldi";
          startupNotify = true;
        };
      };
  };
}
