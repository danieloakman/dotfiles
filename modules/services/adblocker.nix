_:
let
  port = 2899;
in
{
  networking.firewall.allowedTCPPorts = [ port ];

  services.adguardhome = {
    enable = true;
    openFirewall = true;
    port = port;
  };
}
