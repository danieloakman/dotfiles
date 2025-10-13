{ env, ... }: {
  services.n8n = {
    enable = true;
    openFirewall = true;
  };

  home-manager.users.${env.user} = {
    xdg.desktopEntries =
      let
        webapp = url: "uwsm app -- vivaldi --ozone-platform=wayland --app=\"${url}\"";
      in
      {
        n8n = {
          name = "N8N Automation Platform";
          exec = webapp "http://localhost:5678";
          categories = [ "Network" "WebBrowser" ];
          icon = "vivaldi";
          startupNotify = true;
        };
      };
  };
}
