# Orca — agent development environment (ADE).
# https://orca.dev/
# Linux desktop: extracted AppImage + autoPatchelf as `orca-ide` (no bwrap/FHS).
# Darwin: Homebrew cask stablyai/orca/orca.
# Headless runtime: my.programs.orca.serve → orca-server tarball.
{ env
, config
, lib
, pkgs
, ...
}:
let
  cfg = config.my.programs.orca;
  inherit (cfg) serve;

  # Keep in sync with `_package.nix` / `_server.nix` defaults and skills source rev.
  version = "1.4.258";

  orcaSkillNames = [
    "orca-cli"
    "orchestration"
    "orca-computer-use"
    "orca-linear"
    "orca-jira"
    "orca-emulator"
    "orca-emulator-android"
    "orca-per-workspace-env"
    "orca-plugin-authoring"
  ];

  defaultPackage = pkgs.callPackage ./_package.nix { inherit version; };
  defaultServerPackage = pkgs.callPackage ./_server.nix { inherit version; };

  # Sparse checkout of skills/ only (full repo is hundreds of MB).
  # Bump with version:
  #   nix-build -E 'with import <nixpkgs> {}; fetchFromGitHub {
  #     owner="stablyai"; repo="orca"; rev="vVERSION";
  #     sparseCheckout=["skills"]; hash=""; }'  # read "got:"
  orcaSkillsSrc = pkgs.fetchFromGitHub {
    owner = "stablyai";
    repo = "orca";
    rev = "v${version}";
    sparseCheckout = [ "skills" ];
    hash = "sha256-yEeRd1VZuvDsqOpzI/xk5I0LUtOJkn+8M3QihfANeLs=";
  };

  # Desktop package autoPatchelfs the AppImage (no bwrap), so agent PTYs keep
  # privileges. Headless serve still uses the plain Node orca-server tarball.
  orcaUserData = "${env.home}/.config/orca";

  # Darwin: Homebrew cask CLI (`orca`). Linux: ELECTRON_RUN_AS_NODE CLI from the package.
  orcaCli = if env.platform == "darwin" then "orca" else lib.getExe' cfg.package "orca";
  jqBin = lib.getExe pkgs.jq;

  serveArgs =
    [
      "serve"
      "--supervise"
      "--no-pairing"
      "--port"
      (toString serve.port)
      "--pairing-address"
      serve.pairing-address
    ]
    ++ lib.optionals (serve.bind != null) [
      "--bind"
      serve.bind
    ]
    ++ lib.optional serve.refuse-public "--refuse-public"
    ++ lib.optional serve.allow-public "--allow-public";
in
{
  options.my.programs.orca = {
    enable = lib.mkEnableOption ''
      Orca (stablyai/orca): agent development environment. Linux installs the
      pinned AppImage extracted + autoPatchelf'd as `orca-ide` (no bubblewrap);
      Darwin installs the Homebrew cask `stablyai/orca/orca` (not Plotly `orca`).
    '';

    package = lib.mkOption {
      type = lib.types.package;
      default = defaultPackage;
      description = "Orca desktop package (Linux AppImage extract). Unused on Darwin (Homebrew).";
    };

    skills = lib.mkOption {
      type = lib.types.listOf (lib.types.enum orcaSkillNames);
      default = [
        "orca-cli"
        "orchestration"
        "orca-computer-use"
      ];
      description = ''
        Orca discovery stubs to install into `my.programs.agents.skill-dirs`.
        Stubs load version-matched guides via the Orca CLI (`skills get`).
        An empty list installs no Orca skills.
      '';
      example = [
        "orca-cli"
        "orchestration"
        "orca-linear"
      ];
    };

    plugins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "stablyai.orca-nix" ];
      example = [
        "stablyai.orca-nix"
        "stablyai.orca-systemd"
      ];
      description = ''
        Catalog plugin ids (or other `orca plugin install` sources) ensured on
        home-manager activation. Content-only plugins (themes, syntaxes) install
        and enable without approval. Requires an Orca runtime with the plugin
        service (desktop Electron). Headless `orca-serve` (orcad) has no plugin
        service yet — activation warns and continues. Empty list installs nothing.
      '';
    };

    serve = {
      enable = lib.mkEnableOption ''
        Run a headless Orca runtime (`orca-serve serve --supervise --no-pairing`)
        as a Linux systemd user service from the official orca-server tarball
        (plain Node/orcad — no Electron). Pair clients afterward with
        `orca-serve pair --address <pairing-address>` or
        `orca-serve pair --mobile --address <pairing-address>`.
        Requires `my.programs.orca.enable`. Linux only.
      '';

      package = lib.mkOption {
        type = lib.types.package;
        default = defaultServerPackage;
        description = ''
          Headless Orca server package (official `orca-server-linux-*.tar.gz`).
          Exposed on PATH as `orca-serve`. Do not point this at the AppImage.
        '';
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 6768;
        description = "Port for `orca serve` (`--port`).";
      };

      bind = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "0.0.0.0";
        example = "100.116.141.37";
        description = ''
          Listen address (`--bind`). Use `0.0.0.0` or the Tailscale IPv4 so
          akatosh / phone on the tailnet can connect. `null` omits `--bind`
          (Orca's default).
        '';
      };

      pairing-address = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "100.116.141.37";
        description = ''
          Address clients should dial (`--pairing-address`): Tailscale IPv4 or
          MagicDNS name (e.g. mara.dinosaur-crocodile.ts.net). Required when
          `serve.enable` is true. Not `127.0.0.1`.
        '';
      };

      refuse-public = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Pass `--refuse-public` (reject non-LAN/Tailscale clients).";
      };

      allow-public = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Pass `--allow-public`. Mutually exclusive with `refuse-public`.";
      };

      open-firewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Allow `serve.port` on the `tailscale0` interface (same pattern as
          headroom). Leave true when clients reach mara over Tailscale.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = !serve.enable || env.platform == "linux";
            message = "my.programs.orca.serve.enable is only supported on Linux.";
          }
          {
            assertion = !serve.enable || serve.pairing-address != "";
            message = "my.programs.orca.serve.enable requires serve.pairing-address.";
          }
          {
            assertion = !(serve.refuse-public && serve.allow-public);
            message = "my.programs.orca.serve: refuse-public and allow-public are mutually exclusive.";
          }
        ];
      }

      (env.selectPlatform {
        linux = {
          home-manager.users.${env.user}.home.packages = [ cfg.package ];
        };

        darwin = {
          homebrew = {
            # Bare `orca` is Plotly; always use the stablyai tap.
            taps = [
              {
                name = "stablyai/orca";
                trusted = true;
              }
            ];
            casks = [
              {
                name = "stablyai/orca/orca";
                trusted = true;
              }
            ];
          };
        };
      })

      (lib.mkIf (cfg.skills != [ ]) {
        my.programs.agents.skill-dirs = lib.listToAttrs (
          map
            (name: {
              inherit name;
              value = "${orcaSkillsSrc}/skills/${name}";
            })
            cfg.skills
        );
      })

      (lib.mkIf (cfg.plugins != [ ]) {
        home-manager.users.${env.user} =
          { lib, ... }:
          {
            # Best-effort: needs a live Orca host that exposes plugins (not orcad).
            # Never `exit` here — this snippet is inlined into HM activate; exit
            # aborts linkGeneration / sd-switch (e.g. telegram user units).
            home.activation.installOrcaPlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
              export ORCA_USER_DATA_PATH=${lib.escapeShellArg orcaUserData}
              orca_bin=${lib.escapeShellArg orcaCli}
              if [ ! -x "$orca_bin" ]; then
                orca_bin=$(command -v "$orca_bin" 2>/dev/null || true)
              fi
              if [ -z "$orca_bin" ]; then
                echo "orca.plugins: CLI not found; skip"
              else
                list_json=$("$orca_bin" plugin list --json 2>/dev/null || true)
                if ! printf '%s' "$list_json" | ${jqBin} -e '.ok == true' >/dev/null 2>&1; then
                  msg=$(printf '%s' "$list_json" | ${jqBin} -r '.error.message // "plugin list failed"' 2>/dev/null || echo "plugin list failed")
                  echo "orca.plugins: skip ($msg). Needs desktop Electron Orca; headless orcad has no plugin service."
                else
                  $DRY_RUN_CMD "$orca_bin" plugin system on --json >/dev/null 2>&1 || true

                  for id in ${lib.escapeShellArgs cfg.plugins}; do
                    installed=$(printf '%s' "$list_json" | ${jqBin} -r --arg id "$id" '
                      [.result.plugins[]?
                        | select(.id == $id or .pluginKey == $id or .key == $id or .plugin_id == $id)
                        | .id // .pluginKey // .key // empty
                      ] | first // empty
                    ')
                    if [ -n "$installed" ]; then
                      echo "orca.plugins: $id already installed"
                      continue
                    fi
                    echo "orca.plugins: installing $id"
                    # Soft-fail: do not abort home-manager activation if Orca rejects install.
                    $DRY_RUN_CMD "$orca_bin" plugin install "$id" --json \
                      || echo "orca.plugins: failed to install $id" >&2
                    list_json=$("$orca_bin" plugin list --json 2>/dev/null || printf '%s' "$list_json")
                  done
                fi
              fi
            '';
          };
      })

      # selectPlatform (not mkIf + platform): Darwin has no networking.firewall /
      # linger, and inactive mkIf defs still require those options to exist.
      (lib.mkIf serve.enable (env.selectPlatform {
        linux = {
          # Keep the user service up without an interactive login (headless mara).
          users.users.${env.user}.linger = true;

          networking.firewall.interfaces."tailscale0".allowedTCPPorts = lib.mkIf serve.open-firewall [
            serve.port
          ];

          home-manager.users.${env.user} = {
            home.packages = [ serve.package ];
            systemd.user.services.orca-serve = {
              Unit = {
                Description = "Orca headless runtime (orca-server / orcad)";
                Documentation = [
                  "https://orca.dev/docs/remote-servers"
                ];
                After = [ "network-online.target" ];
                Wants = [ "network-online.target" ];
              };
              Service = {
                Type = "simple";
                # Match upstream `orca serve service install`: supervise + no pairing
                # in the unit log. Pair with `orca-serve pair` while this is running.
                # orca-server tarball (plain Node; desktop Electron is separate).
                Environment = [
                  "ORCA_USER_DATA_PATH=${orcaUserData}"
                ];
                ExecStart = lib.escapeShellArgs (
                  [ (lib.getExe serve.package) ] ++ serveArgs
                );
                Restart = "on-failure";
                RestartSec = 5;
                TimeoutStopSec = 30;
                # First start / artifact hydrate can be slow.
                TimeoutStartSec = 120;
              };
              Install.WantedBy = [ "default.target" ];
            };
          };

          my.services.appctl.services.orca = {
            description = "Orca headless runtime";
            units = [ "orca-serve.service" ];
            scope = "user";
            user = env.user;
            memoryHigh = "2G";
            oomScoreAdjust = 350;
          };
        };
      }))
    ]
  );
}
