{ config, ... }:
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

    # tailscale.serve.services = {
    #   "homepage" = {
    #     endpoints = {
    #       "tcp:${toString port}" = "http://localhost:${toString port}";
    #     };
    #     advertised = true;
    #   };
    # };
  };
}
