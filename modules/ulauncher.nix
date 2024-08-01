{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    ulauncher

    # Required for ulauncher extensions:
    python3
    (python3.withPackages (ps: with ps; [
      pip
      requests
      pint
      simpleeval
      parsedatetime
      pytz # TODO: Ulauncher extension "Calculate anything" doesn't start because it can't find pytz module. Need to fix before using.
      babel
    ]))
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
