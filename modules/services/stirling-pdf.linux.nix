{ pkgs, lib, config, env, stirlingPdfPackage, ... }:
let
  cfg = config.my.services.stirlingPdf;
  inherit (cfg) port;
  portStr = toString port;
in
{
  options.my.services.stirlingPdf = {
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

    environment.systemPackages = with pkgs; [
      (writeShellScriptBin "tailscale-svc-stirling-pdf-up" ''
        tailscale serve --service=svc:stirling-pdf --https=443 127.0.0.1:${portStr}
      '')
      (writeShellScriptBin "tailscale-svc-stirling-pdf-down" ''
        tailscale serve clear svc:stirling-pdf
      '')
    ];

    my.services.homepage.services."Stirling PDF" = {
      description = "PDF Viewer";
      # href = "http://${config.networking.hostName}:${toString cfg.port}";
      href = "https://stirling-pdf.dinosaur-crocodile.ts.net";
    };
  };
}
