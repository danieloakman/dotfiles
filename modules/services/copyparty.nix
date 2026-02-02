{ copyparty, pkgs, ... }:
let
  copypartyPort = 3210;
in
{
  imports = [ copyparty.nixosModules.default ];

  services.copyparty = {
    enable = true;
    # directly maps to values in the [global] section of the copyparty config.
    # see `copyparty --help` for available options
    settings = {
      i = "0.0.0.0";
      p = copypartyPort;
    };
  };

  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "tailscale-svc-copyparty-up" ''
      tailscale serve --service=svc:copyparty --https=443 127.0.0.1:${toString copypartyPort}
    '')
    (writeShellScriptBin "tailscale-svc-copyparty-down" ''
      tailscale serve clear svc:copyparty
    '')
  ];
}
