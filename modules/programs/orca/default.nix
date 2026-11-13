# Orca — agent development environment (ADE).
# https://orca.dev/
# Linux: pinned AppImage as `orca-ide`. Darwin: Homebrew cask stablyai/orca/orca.
{ env
, config
, lib
, pkgs
, ...
}:
let
  cfg = config.my.programs.orca;

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
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
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
          map (name: {
            inherit name;
            value = "${orcaSkillsSrc}/skills/${name}";
          }) cfg.skills
        );
      })
    ]
  );
}
