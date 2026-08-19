{ lib, pkgs, config, stirlingPdfPackage, ... }:
let
  cfg = config.my.services.stirling-pdf;
  inherit (cfg) port;
  portStr = toString port;
  unoserver = pkgs.callPackage ./stirling-pdf/_package.nix { };
  unoPort = 2003;
  soffice = lib.getExe' pkgs.libreoffice "soffice";
  # Wrapped soffice tries `mkdir /run/user/$UID` unless a session bus already
  # exists. DynamicUser cannot create that path, so start dbus first.
  unoserverStart = pkgs.writeShellApplication {
    name = "stirling-unoserver";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.dbus
      unoserver
    ];
    text = ''
      export HOME="''${STATE_DIRECTORY:-/var/lib/unoserver}"
      export XDG_RUNTIME_DIR="''${RUNTIME_DIRECTORY:-/run/unoserver}"
      export SAL_USE_VCLPLUGIN=svp
      mkdir -p "$HOME/lo-profile" "$XDG_RUNTIME_DIR"
      exec dbus-run-session -- ${lib.getExe unoserver} \
        --interface 127.0.0.1 \
        --port ${toString unoPort} \
        --uno-port 2002 \
        --executable ${soffice} \
        --user-installation "$HOME/lo-profile"
    '';
  };
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

    # Stirling-PDF 1.5.0 execs `unoconvert` (not the deprecated `unoconv` that
    # the NixOS module puts on PATH). It also treats Python as implying
    # unoconvert is available, so it never falls back to `soffice`.
    systemd.services.unoserver = {
      description = "LibreOffice UNO conversion server for Stirling PDF";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      path = [
        pkgs.dbus
        pkgs.libreoffice
        pkgs.which
      ];
      serviceConfig = {
        Type = "simple";
        ExecStart = lib.getExe unoserverStart;
        # unoserver exits 0 when LibreOffice dies, so on-failure never restarts.
        Restart = "always";
        RestartSec = 5;
        StartLimitIntervalSec = 0;
        DynamicUser = true;
        StateDirectory = "unoserver";
        RuntimeDirectory = "unoserver";
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
      };
    };

    systemd.services.stirling-pdf = {
      after = [ "unoserver.service" ];
      wants = [ "unoserver.service" ];
      path = [ unoserver ];
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
