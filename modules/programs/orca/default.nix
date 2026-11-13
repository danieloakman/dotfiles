# Orca — agent development environment (ADE).
# https://orca.dev/
# Linux: pinned AppImage as `orca-ide`. Darwin: Homebrew cask stablyai/orca/orca.
# Headless runtime: my.programs.orca.serve (Linux user systemd unit).
# Integrations (Settings → Connect integrations) live on the runtime host
# (remote server for `orca serve`), not the client laptop.
{ env
, config
, lib
, pkgs
, ...
}:
let
  cfg = config.my.programs.orca;
  serve = cfg.serve;
  integrations = cfg.integrations;

  # Keep in sync with `_package.nix` default and skills source rev.
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

  orcaBin = lib.getExe cfg.package;

  hasMainGhToken =
    env.platform == "linux" && builtins.hasAttr "main_gh_token" (config.sops.secrets or { });

  integrationPackages = lib.optionals integrations.enable integrations.packages;

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
      pinned AppImage as `orca-ide`; Darwin installs the Homebrew cask
      `stablyai/orca/orca` (not the unrelated Plotly `orca` cask).
    '';

    package = lib.mkOption {
      type = lib.types.package;
      default = defaultPackage;
      description = "Orca package (Linux AppImage wrap). Unused on Darwin (Homebrew).";
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

    integrations = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Install provider CLIs Orca uses under Settings → Connect integrations
          (`integrations.packages`). On Linux with `serve.enable` and
          `sops.secrets.main_gh_token`, also inject `GH_TOKEN` into the
          `orca-serve` user unit so the headless runtime is authenticated
          without an interactive shell.
        '';
      };

      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ pkgs.gh ];
        defaultText = lib.literalExpression "[ pkgs.gh ]";
        example = lib.literalExpression "[ pkgs.gh pkgs.glab ]";
        description = ''
          CLI packages for Orca source-control integrations. These must be on
          the runtime host (e.g. mara for `orca serve`), not only the client.
        '';
      };
    };

    serve = {
      enable = lib.mkEnableOption ''
        Run a headless Orca runtime (`orca-ide serve --supervise --no-pairing`)
        as a Linux systemd user service. Pair clients afterward with
        `orca-ide pair --address <pairing-address>` or
        `orca-ide pair --mobile --address <pairing-address>`.
        Requires `my.programs.orca.enable`. Linux only.
      '';

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
          home-manager.users.${env.user}.home.packages = [ cfg.package ] ++ integrationPackages;
        };

        darwin = {
          environment.systemPackages = integrationPackages;
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
          map (name: {
            inherit name;
            value = "${orcaSkillsSrc}/skills/${name}";
          }) cfg.skills
        );
      })

      (lib.mkIf (serve.enable && env.platform == "linux") (
        lib.mkMerge [
          {
            # Keep the user service up without an interactive login (headless mara).
            users.users.${env.user}.linger = true;

            networking.firewall.interfaces."tailscale0".allowedTCPPorts = lib.mkIf serve.open-firewall [
              serve.port
            ];

            home-manager.users.${env.user} = {
              systemd.user.services.orca-serve = {
                Unit = {
                  Description = "Orca headless runtime (orca-ide serve)";
                  Documentation = [
                    "https://orca.dev/docs/remote-servers"
                  ];
                  After = [ "network-online.target" ];
                  Wants = [ "network-online.target" ];
                };
                Service = {
                  Type = "simple";
                  # Match upstream `orca serve service install`: supervise + no pairing
                  # in the unit log. Pair with `orca-ide pair` while this is running.
                  ExecStart = lib.escapeShellArgs ([ orcaBin ] ++ serveArgs);
                  Restart = "on-failure";
                  RestartSec = 5;
                  TimeoutStopSec = 30;
                  # AppImage / first-run extract can be slow.
                  TimeoutStartSec = 120;
                };
                Install.WantedBy = [ "default.target" ];
              };
            };
          }

          # Headless GitHub auth for integrations. Interactive `gh auth login` /
          # ~/.config/gh is not reliable for every spawn path; GH_TOKEN is.
          (lib.mkIf (integrations.enable && hasMainGhToken) {
            sops.templates."orca-serve.env" = {
              owner = env.user;
              group = "secrets";
              mode = "0440";
              content = ''
                GH_TOKEN=${config.sops.placeholder.main_gh_token}
              '';
            };

            home-manager.users.${env.user}.systemd.user.services.orca-serve = {
              Unit.After = [ "sops-nix.service" ];
              Service.EnvironmentFile = [ config.sops.templates."orca-serve.env".path ];
            };
          })
        ]
      ))
    ]
  );
}
