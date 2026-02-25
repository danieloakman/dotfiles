{ pkgs, ... }:
let
  port = 28981;
  hostname = "0.0.0.0";
  user = "paperless";
in
{
  services.paperless = {
    inherit port user;
    enable = true;
    address = hostname;
    domain = "paperless.dinosaur-crocodile.ts.net";
  };

  users.users.${user}.extraGroups = [ "storage" ];

  networking.firewall = {
    allowedTCPPorts = [ port ];
    allowedUDPPorts = [ port ];
  };

  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "tailscale-svc-paperless-up" ''
      tailscale serve --service=svc:paperless --https=443 127.0.0.1:${toString port}
    '')
    (writeShellScriptBin "tailscale-svc-paperless-down" ''
      tailscale serve clear svc:paperless
    '')
  ];
}
