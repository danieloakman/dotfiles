# herdr-gui — browser dashboard over the Herdr socket.
# https://github.com/powerfooI/herdr-gui
{ env
, config
, lib
, pkgs
, ...
}:
let
  cfg = config.my.programs.herdr;
  gui = cfg.gui;
  guiPackage = pkgs.callPackage ./_package-gui.nix { };
  guiBin = lib.getExe gui.package;

  # Keep loopback; Tailscale Serve is the front door (same pattern as Collie / opencode web).
  skipServe = gui.tailscale-service != null;
in
{
  options.my.programs.herdr.gui = {
    enable = lib.mkEnableOption ''
      Install and run herdr-gui (powerfooI/herdr-gui), a self-hosted browser
      dashboard for Herdr (terminals, file explorer, diffs, session inspect).
      Runs as a user service (systemd on Linux, launchd on macOS) on loopback;
      by default exposure is via Tailscale Service `herdr-gui`. Requires
      `my.programs.herdr.enable`.
    '';

    package = lib.mkOption {
      type = lib.types.package;
      default = guiPackage;
      description = "herdr-gui package (pinned upstream release binary).";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 15735;
      description = "Loopback port for herdr-gui (`PORT`).";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = ''
        Bind address (`HOST`). Keep loopback — Tailscale Serve (or your reverse
        proxy) is the front door.
      '';
    };

    tailscale-service = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "herdr-gui";
      description = ''
        Tailscale Service name (without the `svc:` prefix). When set, this
        module declares the service via `services.tailscale.serve.services`
        (Linux). Must match a service defined in the Tailscale admin console.
        Set null to leave the bridge on loopback only.
      '';
    };

    public-hosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "herdr-gui.tail1234.ts.net" ];
      description = ''
        Public MagicDNS / vanity hostnames used for homepage links when
        `public-url` is unset. Prefer the Tailscale Service name when using
        `tailscale-service`.
      '';
    };

    public-url = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "https://herdr-gui.example.ts.net";
      description = "Public URL for homepage / status links.";
    };

    extra-env = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        HERDR_SOCKET_PATH = "/path/to/herdr.sock";
      };
      description = ''
        Extra environment for the herdr-gui service (`HOST`/`PORT` and update
        disable are set by this module). See herdr-gui README for
        `HERDR_*` / `HERDR_GUI_*` variables.
      '';
    };
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !gui.enable || cfg.enable;
          message = "my.programs.herdr.gui.enable requires my.programs.herdr.enable.";
        }
      ];
    }

    (lib.mkIf (cfg.enable && gui.enable) {
      home-manager.users.${env.user} =
        { lib, ... }:
        let
          serviceEnv =
            [
              "HOST=${gui.host}"
              "PORT=${toString gui.port}"
              # Nix owns the binary; don't auto-update into ~/.local/bin.
              "HERDR_GUI_DISABLE_UPDATE_CHECK=1"
              "HERDR_GUI_RESTART_SUPERVISOR=1"
            ]
            ++ lib.mapAttrsToList (name: value: "${name}=${value}") gui.extra-env;
        in
        {
          home.packages = [ gui.package ];

          systemd.user.services.herdr-gui = lib.mkIf (env.platform == "linux") {
            Unit = {
              Description = "herdr-gui (browser dashboard for Herdr)";
              Documentation = [ "https://github.com/powerfooI/herdr-gui" ];
              After = [ "network-online.target" ];
              Wants = [ "network-online.target" ];
            };
            Service = {
              Type = "simple";
              ExecStart = guiBin;
              Restart = "always";
              RestartSec = 2;
              TimeoutStopSec = 15;
              Environment = serviceEnv;
            };
            Install.WantedBy = [ "default.target" ];
          };

          launchd.agents.herdr-gui = lib.mkIf (env.platform == "darwin") {
            enable = true;
            config = {
              Label = "dev.herdr.gui";
              ProgramArguments = [ guiBin ];
              KeepAlive = true;
              RunAtLoad = true;
              EnvironmentVariables = lib.listToAttrs (
                map
                  (
                    line:
                    let
                      parts = lib.splitString "=" line;
                    in
                    {
                      name = builtins.head parts;
                      value = lib.concatStringsSep "=" (builtins.tail parts);
                    }
                  )
                  serviceEnv
              );
            };
          };
        };
    })

    (lib.mkIf (cfg.enable && gui.enable && env.platform == "linux") {
      services.tailscale.serve.services = lib.mkIf skipServe {
        ${gui.tailscale-service} = {
          endpoints."tcp:443" = "http://${gui.host}:${toString gui.port}";
        };
      };

      my.services.homepage.services."herdr-gui" = {
        description = "Herdr browser dashboard";
        href =
          if gui.public-url != null then
            gui.public-url
          else if gui.public-hosts != [ ] then
            "https://${builtins.head gui.public-hosts}"
          else
            "https://${config.networking.hostName}";
      };
    })
  ];
}
