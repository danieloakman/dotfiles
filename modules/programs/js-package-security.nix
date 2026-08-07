# Harden npm, pnpm, and bun against supply-chain attacks.
# https://github.com/lirantal/npm-security-best-practices
{ env, config, lib, ... }:
let
  cfg = config.my.programs.js-package-security;

  minReleaseAgeMinutes = cfg.min-release-age-days * 24 * 60;
  minReleaseAgeSeconds = cfg.min-release-age-days * 24 * 60 * 60;

  privateRegistryLines = lib.concatMapStringsSep "\n"
    (
      { scope, registry }: "${scope}:registry=${registry}"
    )
    cfg.private-registries;

  npmSecurityFragment =
    let
      lines = [
        "# npm security defaults (dotfiles: my.programs.js-package-security)"
        "# https://github.com/lirantal/npm-security-best-practices"
        ""
        (lib.optionalString cfg.ignore-scripts "ignore-scripts=true")
        "allow-git=${cfg.allow-git}"
        "min-release-age=${toString cfg.min-release-age-days}"
      ]
      ++ lib.optional (privateRegistryLines != "") privateRegistryLines;
    in
    lib.concatStringsSep "\n" lines;

  pnpmConfigYaml = lib.generators.toYAML { } {
    minimumReleaseAge = minReleaseAgeMinutes;
    minimumReleaseAgeExclude = cfg.minimum-release-age-exclude;
    trustPolicy = "no-downgrade";
    blockExoticSubdeps = true;
    strictDepBuilds = true;
    allowBuilds = lib.genAttrs cfg.allow-builds (_: true);
  };

  bunfigToml = ''
    # bun security defaults (dotfiles: my.programs.js-package-security)
    # https://github.com/lirantal/npm-security-best-practices

    [install]
    minimumReleaseAge = ${toString minReleaseAgeSeconds}
    minimumReleaseAgeExcludes = ${builtins.toJSON cfg.minimum-release-age-exclude}
  '';

  npmrcAuthTemplate = ''
    # Private registry auth (not managed by dotfiles — preserved across rebuilds).
    # Add tokens here manually, or run:
    #   npm login --registry=https://npm.example.com/ --scope=@example
    # pnpm stores auth separately in ~/.config/pnpm/auth.ini (or ~/Library/Preferences/pnpm/auth.ini on macOS).
    #
    # Example:
    # //npm.example.com/:_authToken=${"$"}{NPM_TOKEN}
  '';

  pnpmConfigPath = env.selectPlatform {
    linux = ".config/pnpm/config.yaml";
    darwin = "Library/Preferences/pnpm/config.yaml";
  };
in
{
  options.my.programs.js-package-security = {
    enable = lib.mkEnableOption ''
      Harden npm, pnpm, and bun against supply-chain attacks (lifecycle scripts,
      git deps, release cooldown, pnpm trust policy).
    '';

    min-release-age-days = lib.mkOption {
      type = lib.types.int;
      default = 7;
      description = "Minimum age in days before a newly published package version can be installed.";
    };

    ignore-scripts = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Disable npm lifecycle scripts (postinstall, etc.) globally.
        Override per project in .npmrc or with npm install --ignore-scripts=false when needed.
      '';
    };

    allow-git = lib.mkOption {
      type = lib.types.enum [
        "none"
        "root"
        "all"
      ];
      default = "none";
      description = ''
        npm allow-git policy. "none" blocks all git-based deps; "root" allows them only in the
        root package.json; "all" is npm's default.
      '';
    };

    allow-builds = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "esbuild"
        "rolldown"
        "unrs-resolver"
      ];
      description = "pnpm packages permitted to run install/build lifecycle scripts.";
    };

    minimum-release-age-exclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "@types/bun"
        "typescript"
      ];
      description = "Packages that bypass the minimum release age cooldown.";
    };

    private-registries = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            scope = lib.mkOption {
              type = lib.types.str;
              description = "npm scope including @, e.g. @mycompany";
            };
            registry = lib.mkOption {
              type = lib.types.str;
              description = "Private registry URL, e.g. https://npm.mycompany.com/";
            };
          };
        }
      );
      default = [ ];
      example = [
        {
          scope = "@mycompany";
          registry = "https://npm.mycompany.com/";
        }
      ];
      description = ''
        Scoped private registry routing (URLs only). Auth tokens belong in ~/.npmrc.auth
        or via npm/pnpm login — never commit tokens to dotfiles.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${env.user} =
      { lib, ... }:
      {
        home.file = {
          ".config/npm/security.npmrc".text = npmSecurityFragment;

          ".npmrc.auth.example".text = npmrcAuthTemplate;

          ".npmrc.auth" = {
            text = npmrcAuthTemplate;
            force = false;
          };

          "${pnpmConfigPath}".text = pnpmConfigYaml;

          ".bunfig.toml".text = bunfigToml;
        };

        home.activation.mergeNpmrc = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          $DRY_RUN_CMD cp ${env.home}/.config/npm/security.npmrc ${env.home}/.npmrc
          if [ -f ${env.home}/.npmrc.auth ]; then
            $DRY_RUN_CMD printf '\n' >> ${env.home}/.npmrc
            $DRY_RUN_CMD cat ${env.home}/.npmrc.auth >> ${env.home}/.npmrc
          fi
        '';
      };
  };
}
