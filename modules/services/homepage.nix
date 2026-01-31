{ config, pkgs, ... }:
let
  port = 9092;
  host = config.networking.hostName;
in
{
  networking.firewall.allowedTCPPorts = [ port ];

  services = {
    homepage-dashboard = {
      enable = true;
      allowedHosts = "${host}:${toString port},localhost:${toString port}";
      openFirewall = true;
      listenPort = port;
    };
  };

  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "tailscale-svc-homepage-up" ''
      tailscale serve --service=svc:homepage --https=443 127.0.0.1:${toString port}
    '')
    (writeShellScriptBin "tailscale-svc-homepage-down" ''
      tailscale serve clear svc:homepage
    '')
  ];
}
