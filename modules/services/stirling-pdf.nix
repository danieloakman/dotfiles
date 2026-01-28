_:
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

    # tailscale.serve.services = {
    #   "stirling-pdf" = {
    #     endpoints = {
    #       "tcp:${portStr}" = "http://localhost:${portStr}";
    #     };
    #     advertised = true;
    #   };
    # };
  };

}
