{ pkgs, lib, config, ... }:
let
  cfg = config.my.services.paperless;
  port = cfg.port;
  hostname = "127.0.0.1";
  user = "paperless";
in
{
  options.my.services.paperless = {
    enable = lib.mkEnableOption "Enable the Paperless service";
    port = lib.mkOption {
      type = lib.types.int;
      default = 28981;
    };
    domain = lib.mkOption {
      type = lib.types.str;
      description = "The domain to use for the Paperless service";
    };
    mediaDir = lib.mkOption {
      type = lib.types.str;
      description = "The directory to use for the Paperless media files";
    };
  };

  config = lib.mkIf config.my.services.paperless.enable ({
    assertions = [
      {
        assertion = cfg.domain != null;
        message = "paperless.domain must be set";
      }
      {
        assertion = cfg.mediaDir != null;
        message = "paperless.mediaDir must be set";
      }
    ];

    services.paperless = {
      inherit port user;
      enable = true;
      address = hostname;
      domain = cfg.domain;
    };

    users.users.${user}.extraGroups = [ "storage" ];

    networking.firewall = {
      allowedTCPPorts = [ port ];
      allowedUDPPorts = [ port ];
    };

    environment.systemPackages = with pkgs; [
      (writeShellScriptBin "tailscale-svc-paperless-up" ''
        tailscale serve --service=svc:paperless --https=443 ${hostname}:${toString port}
      '')
      (writeShellScriptBin "tailscale-svc-paperless-down" ''
        tailscale serve clear svc:paperless
      '')
    ];

    my.services.homepage.services."Paperless" = {
      description = "Document management";
      href = "https://paperless.dinosaur-crocodile.ts.net";
    };
  });
}
