{ pkgs, ... }:
let
  port = 19091;
  portStr = toString port;
in
{
  networking.firewall.allowedTCPPorts = [ port ];

  services = {
    stirling-pdf = {
      enable = true;
      environment = {
        SERVER_PORT = portStr;
        SYSTEM_ENABLEANALYTICS = "false";
      };
    };
  };

  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "tailscale-svc-stirling-pdf-up" ''
      tailscale serve --service=svc:stirling-pdf --https=443 127.0.0.1:${portStr}
    '')
    (writeShellScriptBin "tailscale-svc-stirling-pdf-down" ''
      tailscale serve clear svc:stirling-pdf
    '')
  ];
}
