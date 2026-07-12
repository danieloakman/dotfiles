# Herdr — terminal multiplexer for AI agents.
# https://herdr.dev
{ env
, config
, lib
, pkgs
, ...
}:
let
  cfg = config.my.programs.herdr;
  version = pkgs.herdr.version;

  # build.rs shells out to zig to compile vendored libghostty-vt. On Darwin,
  # zig's libc/SDK discovery relies on xcrun + system libtool, which aren't
  # available in the Nix sandbox, so use upstream release binaries on macOS.
  binaryAssetMap = {
    x86_64-darwin = "herdr-macos-x86_64";
    aarch64-darwin = "herdr-macos-aarch64";
  };

  binaryHashes = {
    x86_64-darwin = "sha256-V4D6B9u5p4155S0guGphAT9sugJmfyC2z4lmMBUJCEY=";
    aarch64-darwin = "sha256-FvRlPwSR6h59K0a1sCVC8Y4bguiNqvnikAVy5btjTfg=";
  };

  # Claude Code integration: keep in sync with install_claude() in
  # ${pkgs.herdr.src}/src/integration/mod.rs. After herdr upgrades, run:
  #   herdr integration status --outdated-only
  herdrClaudeHookScript = "${pkgs.herdr.src}/src/integration/assets/claude/herdr-agent-state.sh";

  herdrDarwin = pkgs.stdenvNoCC.mkDerivation {
    pname = "herdr";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/ogulcancelik/herdr/releases/download/v${version}/${
        binaryAssetMap.${pkgs.stdenv.hostPlatform.system}
          or (throw "my.programs.herdr: unsupported Darwin system ${pkgs.stdenv.hostPlatform.system}")
      }";
      hash = binaryHashes.${pkgs.stdenv.hostPlatform.system};
    };

    dontUnpack = true;

    installPhase = ''
      install -Dm755 $src $out/bin/herdr
    '';

    meta = pkgs.herdr.meta // {
      sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    };
  };

in
{
  options.my.programs.herdr = {
    enable = lib.mkEnableOption ''
      Herdr (ogulcancelik/herdr): install and configure the agent terminal multiplexer
    '';
  };

  config = lib.mkIf cfg.enable {
    my.programs.agents.skills.herdr = builtins.fetchurl {
      url = "https://raw.githubusercontent.com/ogulcancelik/herdr/master/SKILL.md";
      sha256 = "sha256-dYJkUsoJYjpzCcCg2b1rKbJMVc8QBjL8g71ppoUkHxc=";
    };

    home-manager.users.${env.user} = lib.mkMerge [
      {
        programs.herdr = ({
          enable = true;
          # https://herdr.dev/docs/configuration/#_top
          settings = {
            onboarding = false;
            terminal.default_shell = "zsh";
            update.version_check = false;
            ui = {
              toast = {
                delivery = if env.deviceType == "server" then "herdr" else "system";
                herdr.position = "bottom-right";
              };
            };
          };
        } // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
          package = herdrDarwin;
        });
      }
      (lib.mkIf config.my.programs.claude-code.enable {
        home.file.".claude/hooks/herdr-agent-state.sh" = {
          source = herdrClaudeHookScript;
          executable = true;
        };

        programs.claude-code.settings.hooks.SessionStart = [
          {
            matcher = "*";
            hooks = [
              {
                type = "command";
                command = "bash ${env.home}/.claude/hooks/herdr-agent-state.sh session";
                timeout = 10;
              }
            ];
          }
        ];
      })
    ];
  };
}
