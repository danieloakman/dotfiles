{ pkgs, ... }:
let
  ulauncher = pkgs.ulauncher.overrideAttrs
    (oldAttrs: {
      propagatedBuildInputs = oldAttrs.propagatedBuildInputs ++ (with pkgs; [
        python3
        # These are needed for our ulauncher plugins
        python3Packages.pip
        python3Packages.requests
        python3Packages.pint
        python3Packages.simpleeval
        python3Packages.parsedatetime
        python3Packages.pytz
        python3Packages.babel
      ]);
    });
in
{
  environment.systemPackages = [
    ulauncher
  ];

  systemd.user.services.ulauncher = {
    enable = true;
    description = "Start Ulauncher";
    script = "${pkgs.ulauncher}/bin/ulauncher --hide-window";

    documentation = [ "https://github.com/Ulauncher/Ulauncher/blob/f0905b9a9cabb342f9c29d0e9efd3ba4d0fa456e/contrib/systemd/ulauncher.service" ];
    # `systemctl --user --type target,service` to see what's available
    wantedBy = [ "graphical-session.target" "default.target" ];
    after = [ "gnome-session-monitor.service" ];
  };

  # Turned off since some extensions read and modify the settings.json file, which cause them to crash on startup.
  # TODO: modify it using a startup script ins`tead.
  # home-manager.users.${env.user}.home = {
  #   # "hotkey-show-app" has been unset because <Super>space doesn't seem to work. So we're just setting the hotkey in gnome (imperatively) instead.
  #   file.".config/ulauncher/settings.json".text = ''
  #     {
  #       "hotkey-show-app": "",
  #       "blacklisted-desktop-dirs": "/usr/share/locale:/usr/share/app-install:/usr/share/kservices5:/usr/share/fk5:/usr/share/kservicetypes5:/usr/share/applications/screensavers:/usr/share/kde4:/usr/share/mimelnk",
  #       "clear-previous-query": true,
  #       "disable-desktop-filters": false,
  #       "grab-mouse-pointer": false,
  #       "render-on-screen": "mouse-pointer-monitor",
  #       "show-indicator-icon": true,
  #       "show-recent-apps": "0",
  #       "terminal-command": "",
  #       "theme-name": "dark"
  #     }
  #   '';
  # };
}
