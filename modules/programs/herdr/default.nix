# Herdr — terminal multiplexer for AI agents.
# https://herdr.dev
# Optional UIs: Collie (./collie.nix), herdr-gui (./gui.nix)
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
    # x86_64-darwin = "herdr-macos-x86_64";
    aarch64-darwin = "herdr-macos-aarch64";
  };

  # Must match pkgs.herdr.version. Prefetch after a nixpkgs bump:
  #   nix store prefetch-file "https://github.com/ogulcancelik/herdr/releases/download/vVERSION/herdr-macos-aarch64"
  binaryHashes = {
    "0.7.4" = {
      # x86_64-darwin = "sha256-V4D6B9u5p4155S0guGphAT9sugJmfyC2z4lmMBUJCEY=";
      aarch64-darwin = "sha256-JJkuFiXb3LGDVKWeKZ5LJjwxJACzE5bNwHzUbtV/JKc=";
    };
    "0.8.0" = {
      aarch64-darwin = "sha256-1Tqfk/zP38xVYyknv1EAL1rdCqeZC831CP+9hKxlgXg=";
    };
  };

  herdrDarwin = pkgs.stdenvNoCC.mkDerivation {
    pname = "herdr";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/ogulcancelik/herdr/releases/download/v${version}/${
        binaryAssetMap.${pkgs.stdenv.hostPlatform.system}
          or (throw "my.programs.herdr: unsupported Darwin system ${pkgs.stdenv.hostPlatform.system}")
      }";
      hash =
        (binaryHashes.${version} or (throw "my.programs.herdr: add Darwin binaryHashes.\"${version}\" (see comment above)")).${pkgs.stdenv.hostPlatform.system}
          or (throw "my.programs.herdr: missing Darwin hash for ${pkgs.stdenv.hostPlatform.system} at ${version}");
    };

    dontUnpack = true;

    installPhase = ''
      install -Dm755 $src $out/bin/herdr
    '';

    meta = pkgs.herdr.meta // {
      sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    };
  };

  defaultPackage = if env.platform == "darwin" then herdrDarwin else pkgs.herdr;
in
{
  options.my.programs.herdr = {
    enable = lib.mkEnableOption ''
      Herdr (ogulcancelik/herdr): install and configure the agent terminal multiplexer
    '';

    package = lib.mkOption {
      type = lib.types.package;
      default = defaultPackage;
      description = "Herdr package (upstream release binary on Darwin; nixpkgs elsewhere).";
    };
  };

  config = lib.mkIf cfg.enable {
    my.programs.agents.skills.herdr = builtins.fetchurl {
      url = "https://raw.githubusercontent.com/ogulcancelik/herdr/master/SKILL.md";
      sha256 = "sha256-dYJkUsoJYjpzCcCg2b1rKbJMVc8QBjL8g71ppoUkHxc=";
    };

    home-manager.users.${env.user} = {
      programs.herdr = {
        enable = true;
        package = cfg.package;
        # https://herdr.dev/docs/configuration/#_top
        settings = {
          onboarding = false;
          terminal.default_shell = "zsh";
          update.version_check = false;
          worktrees.directory = "~/repos/worktrees";
          ui = {
            toast = {
              delivery = if env.deviceType == "server" then "herdr" else "system";
              herdr.position = "bottom-right";
            };
          };
        };
      };
    };
  };
}
