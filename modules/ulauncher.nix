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
    # TODO: probably should move ulauncher.nix to be a gnome dependent module
    after = [ "gnome-session-monitor.service" ];
  };

  # TODO: move ~/.config/ulauncher files to home-manager
}
