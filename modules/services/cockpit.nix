{ pkgs, ... }:
let
  port = "9090";
in
{
  services = {
    cockpit = {
      enable = true;
      openFirewall = true;
      # settings = {};
      allowed-origins = [
        "https://mara:${port}"
        "https://mara-cockpit.tail9f1d8.ts.net"
        "https://mara-cockpit.dinosaur-crocodile.ts.net"
      ];
    };
  };

  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "tailscale-svc-cockpit-up" ''
      tailscale serve --service=svc:mara-cockpit --https=443 127.0.0.1:${toString port}
    '')
    (writeShellScriptBin "tailscale-svc-cockpit-down" ''
      tailscale serve clear svc:mara-cockpit
    '')
  ];
}
