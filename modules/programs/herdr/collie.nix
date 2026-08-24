# Collie — mobile PWA bridge for Herdr (herdr plugin).
# https://github.com/AltanS/collie
{ env
, config
, lib
, pkgs
, ...
}:
let
  cfg = config.my.programs.herdr;
  collie = cfg.collie;
  herdrBin = lib.getExe cfg.package;

  colliePluginId = "herdr.collie";
  collieSource = "AltanS/collie";
  collieConfigRel = "herdr/plugins/config/${colliePluginId}";

  # Tailscale Service front door: Collie stays loopback-only; we publish with
  # `tailscale serve --service=svc:…` (same pattern as cockpit / opencode / etc.).
  collieSkipServe = collie.skip-serve || collie.tailscale-service != null;
  collieTailscaleService = collie.tailscale-service;
  collieWebPush = collie.web-push.enable;
  hasCollieVapidSecrets =
    env.platform == "linux"
    && builtins.hasAttr "collie_vapid_public" (config.sops.secrets or { })
    && builtins.hasAttr "collie_vapid_private" (config.sops.secrets or { });

  collieVapidSubject =
    if collie.web-push.subject != null then
      collie.web-push.subject
    else if collie.trusted-user != null && lib.hasInfix "@" collie.trusted-user then
      "mailto:${collie.trusted-user}"
    else
      null;

  collieEnvLines =
    [
      "# Managed by my.programs.herdr.collie — edits here are overwritten on rebuild."
      "COLLIE_PORT=${toString collie.port}"
      "COLLIE_HOST=${collie.host}"
      "COLLIE_SERVE_MODE=${collie.serve-mode}"
      "COLLIE_MULTI_SESSION=${if collie.multi-session then "on" else "off"}"
    ]
    ++ lib.optional collieSkipServe "COLLIE_SKIP_SERVE=1"
    ++ lib.optional (collie.trusted-user != null) "COLLIE_TRUSTED_USER=${collie.trusted-user}"
    ++ lib.optional (collie.public-hosts != [ ]) "COLLIE_PUBLIC_HOSTS=${lib.concatStringsSep "," collie.public-hosts}"
    ++ lib.optional (collie.allowed-origins != [ ]) "COLLIE_ALLOWED_ORIGINS=${lib.concatStringsSep "," collie.allowed-origins}"
    ++ lib.optional (collie.public-url != null) "COLLIE_PUBLIC_URL=${collie.public-url}"
    ++ lib.mapAttrsToList (name: value: "${name}=${value}") collie.extra-env;

  # Non-secret .env body (nix store). VAPID keys are merged via sops template when web-push is on.
  collieEnvText = lib.concatStringsSep "\n" collieEnvLines + "\n";

  colliePath = lib.makeBinPath [
    pkgs.bash
    pkgs.bun
    pkgs.coreutils
    pkgs.git
    pkgs.jq
    pkgs.gnugrep
    cfg.package
  ] + ":/run/current-system/sw/bin${lib.optionalString (env.platform == "darwin") ":/usr/bin:/bin"}";

  collieIsRunningCheck =
    if env.platform == "darwin" then
      ''launchctl print "gui/$(id -u)/herdr.collie" >/dev/null 2>&1''
    else
      ''systemctl --user is-active --quiet collie'';

  collieRestartSnippet = ''
    export PATH=${lib.escapeShellArg colliePath}
    if ${collieIsRunningCheck}; then
      ${herdrBin} plugin action invoke restart --plugin ${colliePluginId} || true
    fi
  '';
in
{
  options.my.programs.herdr.collie = {
    enable = lib.mkEnableOption ''
      Install and configure Collie (AltanS/collie), the mobile PWA bridge for
      Herdr. Uses `herdr plugin install`, writes the plugin `.env`, and
      optionally starts the bridge (systemd --user on Linux, launchd on macOS).
      By default exposure is via Tailscale Service `herdr-collie` (see
      `tailscale-service`). Requires `my.programs.herdr.enable`.
    '';

    auto-start = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        On Home Manager activation, install the plugin if missing and invoke
        Collie's `start` action when the bridge is not already running.
      '';
    };

    ref = lib.mkOption {
      type = lib.types.str;
      default = "v0.32.0";
      description = ''
        Git ref passed to `herdr plugin install AltanS/collie --ref …`.
        Pin a tag for reproducible installs; use `main` to track upstream tip.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 15734;
      description = "Loopback port for the Collie bridge (`COLLIE_PORT`).";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = ''
        Bind address for the Collie bridge (`COLLIE_HOST`). Keep loopback —
        Tailscale Serve (or your reverse proxy) is the front door.
      '';
    };

    tailscale-service = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "herdr-collie";
      description = ''
        Tailscale Service name (without the `svc:` prefix). When set, Collie
        skips its built-in `tailscale serve` and this module declares the
        service via `services.tailscale.serve.services` (Linux). Must match a
        service defined in the Tailscale admin console. Set null to use
        Collie's built-in MagicDNS Serve instead.
      '';
    };

    serve-mode = lib.mkOption {
      type = lib.types.enum [
        "https"
        "http"
      ];
      default = "https";
      description = ''
        How `collie-ctl.sh start` publishes via built-in `tailscale serve`
        (`COLLIE_SERVE_MODE`) when `tailscale-service` is null. Use `http`
        for Headscale / `.internal` hosts without HTTPS certs (then set
        `public-hosts`).
      '';
    };

    skip-serve = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Skip Collie's built-in `tailscale serve` and leave the bridge on
        loopback only (`COLLIE_SKIP_SERVE=1`). Implied when
        `tailscale-service` is set. Also use for a reverse proxy / tunnel
        (Variant C/E). Pair with `allowed-origins` and `public-hosts`.
      '';
    };

    multi-session = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Serve every named Herdr session under the config root
        (`COLLIE_MULTI_SESSION`). Set false to pin the primary session only.
      '';
    };

    trusted-user = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "you@example.com";
      description = ''
        Tailscale login that may drive agents (`COLLIE_TRUSTED_USER`). Strongly
        recommended — without it any device on your tailnet that reaches the
        URL has full write access.
      '';
    };

    public-hosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "mara.tail1234.ts.net" ];
      description = ''
        Exact Host header values Collie accepts (`COLLIE_PUBLIC_HOSTS`). Set to
        your MagicDNS name(s) to block DNS rebinding. Effectively mandatory
        when `serve-mode = "http"`.
      '';
    };

    allowed-origins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "https://collie.example.com" ];
      description = ''
        Extra browser origins allowed past the same-origin gate
        (`COLLIE_ALLOWED_ORIGINS`). Needed when a vanity domain or reverse
        proxy fronts Collie; plain MagicDNS Serve usually does not need this.
      '';
    };

    public-url = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "https://collie.example.com";
      description = ''
        Public URL shown by `collie-ctl.sh status` when `skip-serve` is set
        (`COLLIE_PUBLIC_URL`).
      '';
    };

    extra-env = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        COLLIE_POLL_MS = "1500";
        COLLIE_TRANSCRIPT = "on";
      };
      description = ''
        Additional `KEY=value` entries written to Collie's `.env` (for example
        transcript roots). Prefer `web-push` for VAPID keys so the private key
        stays in sops rather than the Nix store. Keys should be `COLLIE_*` /
        `HERDR_SOCKET_PATH` as documented in Collie's `.env.example`.
      '';
    };

    web-push = {
      enable = lib.mkEnableOption ''
        Enable Collie Web Push (blocked/done agent alerts). Requires HTTPS
        (Tailscale Serve qualifies), sops secrets `collie_vapid_public` /
        `collie_vapid_private`, and Linux (sops-nix). Generates Collie's
        `.env` via a sops template so VAPID material never enters the store.
      '';

      subject = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "mailto:you@example.com";
        description = ''
          VAPID subject (`COLLIE_VAPID_SUBJECT`). Defaults to
          `mailto:<trusted-user>` when `trusted-user` is an email address.
        '';
      };
    };
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !collie.enable || cfg.enable;
          message = "my.programs.herdr.collie.enable requires my.programs.herdr.enable.";
        }
        {
          assertion =
            !collie.enable
            || collie.serve-mode != "http"
            || collie.public-hosts != [ ]
            || collieSkipServe;
          message = ''
            my.programs.herdr.collie.serve-mode = "http" requires public-hosts
            (DNS rebinding defense) unless skip-serve / tailscale-service is set.
          '';
        }
        {
          assertion =
            !collie.enable
            || collie.tailscale-service == null
            || collie.public-hosts != [ ];
          message = ''
            my.programs.herdr.collie.tailscale-service requires public-hosts set
            to the service MagicDNS name (e.g. herdr-collie.<tailnet>.ts.net).
          '';
        }
        {
          assertion = !collie.enable || !collieWebPush || env.platform == "linux";
          message = "my.programs.herdr.collie.web-push.enable is only supported on Linux (sops-nix).";
        }
        {
          assertion = !collie.enable || !collieWebPush || hasCollieVapidSecrets;
          message = ''
            my.programs.herdr.collie.web-push.enable requires sops secrets
            collie_vapid_public and collie_vapid_private.
          '';
        }
        {
          assertion = !collie.enable || !collieWebPush || collieVapidSubject != null;
          message = ''
            my.programs.herdr.collie.web-push.enable requires web-push.subject
            (or trusted-user set to an email so mailto: can be derived).
          '';
        }
      ];
    }

    (lib.mkIf (cfg.enable && collie.enable) {
      home-manager.users.${env.user} =
        { lib, ... }:
        {
          home.packages = [
            pkgs.bun
            pkgs.git
          ];

          # Plain .env only when VAPID is not injected via sops (secrets must not hit the store).
          xdg.configFile."${collieConfigRel}/.env" = lib.mkIf (!collieWebPush) {
            text = collieEnvText;
            onChange = collieRestartSnippet;
          };

          home.activation.installHerdrCollie = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            export PATH=${lib.escapeShellArg colliePath}
            export HOME=${lib.escapeShellArg env.home}
            export XDG_CONFIG_HOME="''${XDG_CONFIG_HOME:-$HOME/.config}"
            config_dir="$XDG_CONFIG_HOME/${collieConfigRel}"
            $DRY_RUN_CMD mkdir -p "$config_dir"

            ${lib.optionalString collieWebPush ''
              echo "herdr.collie: installing sops-rendered .env (web-push)"
              $DRY_RUN_CMD install -m 0600 ${config.sops.templates."herdr-collie.env".path} "$config_dir/.env"
            ''}

            installed_ref=$(${herdrBin} plugin list --json 2>/dev/null \
              | ${lib.getExe pkgs.jq} -r '
                  .result.plugins[]?
                  | select(.plugin_id == "${colliePluginId}" or .id == "${colliePluginId}")
                  | .source.requested_ref // empty
                ' | head -n1 || true)

            if [ -z "$installed_ref" ]; then
              echo "herdr.collie: installing ${collieSource}@${collie.ref}"
              $DRY_RUN_CMD ${herdrBin} plugin install ${collieSource} \
                --ref ${lib.escapeShellArg collie.ref} --yes
            elif [ "$installed_ref" != ${lib.escapeShellArg collie.ref} ]; then
              echo "herdr.collie: updating ${collieSource} $installed_ref → ${collie.ref}"
              $DRY_RUN_CMD ${herdrBin} plugin install ${collieSource} \
                --ref ${lib.escapeShellArg collie.ref} --yes
            fi

            ${lib.optionalString collieWebPush ''
              # optionalDependency — ensure it is present for push delivery.
              plugin_root=$(${herdrBin} plugin list --json 2>/dev/null \
                | ${lib.getExe pkgs.jq} -r '
                    .result.plugins[]?
                    | select(.plugin_id == "${colliePluginId}" or .id == "${colliePluginId}")
                    | .plugin_root // .path // .root // .directory // empty
                  ' | head -n1 || true)
              if [ -n "$plugin_root" ] && [ -d "$plugin_root" ]; then
                echo "herdr.collie: ensuring web-push in $plugin_root"
                $DRY_RUN_CMD ${lib.getExe pkgs.bun} add --cwd "$plugin_root" web-push || true
              fi
            ''}

            ${lib.optionalString collie.auto-start ''
              if ! ${collieIsRunningCheck}; then
                echo "herdr.collie: starting bridge"
                $DRY_RUN_CMD ${herdrBin} plugin action invoke start --plugin ${colliePluginId} || true
              ${lib.optionalString collieWebPush ''
              else
                # Refresh after sops-rendered .env / web-push dependency install.
                ${collieRestartSnippet}
              ''}
              fi
            ''}
          '';
        };
    })

    (lib.optionalAttrs (env.platform == "linux") (lib.mkIf (cfg.enable && collie.enable && collieWebPush) {
      sops.templates."herdr-collie.env" = {
        owner = env.user;
        group = "secrets";
        mode = "0440";
        content =
          collieEnvText
          + lib.concatStringsSep "\n" [
            "COLLIE_VAPID_PUBLIC=${config.sops.placeholder.collie_vapid_public}"
            "COLLIE_VAPID_PRIVATE=${config.sops.placeholder.collie_vapid_private}"
            "COLLIE_VAPID_SUBJECT=${collieVapidSubject}"
            ""
          ];
      };
    }))

    (lib.optionalAttrs (env.platform == "linux") (lib.mkIf (cfg.enable && collie.enable) {
      services.tailscale.serve.services = lib.mkIf (collieTailscaleService != null) {
        ${collieTailscaleService} = {
          endpoints."tcp:443" = "http://${collie.host}:${toString collie.port}";
        };
      };

      my.services.homepage.services."Collie" = {
        description = "Herdr mobile PWA (Collie)";
        href =
          if collie.public-url != null then
            collie.public-url
          else if collie.public-hosts != [ ] then
            "https://${builtins.head collie.public-hosts}"
          else
            "https://${config.networking.hostName}";
      };
    }))
  ];
}
