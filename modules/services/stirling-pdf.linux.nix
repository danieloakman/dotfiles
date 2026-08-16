{ lib, config, stirlingPdfPackage, ... }:
let
  cfg = config.my.services.stirling-pdf;
  inherit (cfg) port;
  portStr = toString port;
in
{
  options.my.services.stirling-pdf = {
    enable = lib.mkEnableOption "Enable the Stirling PDF service";
    port = lib.mkOption {
      type = lib.types.int;
      default = 19091;
    };
  };

  config = lib.mkIf cfg.enable {
    services = {
      stirling-pdf = {
        enable = true;
        package = stirlingPdfPackage;
        environment = {
          SERVER_PORT = portStr;
          SYSTEM_ENABLEANALYTICS = "false";
        };
      };
    };

    services.tailscale.serve.services.stirling-pdf = {
      endpoints."tcp:443" = "http://127.0.0.1:${portStr}";
    };

    my.services.homepage.services."Stirling PDF" = {
      description = "PDF Viewer";
      # href = "http://${config.networking.hostName}:${toString cfg.port}";
      href = "https://stirling-pdf.dinosaur-crocodile.ts.net";
    };
  };
}
