{ pkgs, ... }:
let
  ulauncher = pkgs.ulauncher.overrideAttrs
    (oldAttrs: {
      propagatedBuildInputs = oldAttrs.propagatedBuildInputs ++ (with pkgs; [
        python3
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
    wantedBy = [ "graphical.target" "multi-user.target" ];
    after = [ "display-manager.service" ];
  };
}
