# Dotfiles glue for telegram-bots (evolved from agent-telegram-bot).
#
# Host values and sops stay here; systemd units live in upstream
# homeManagerModules.default → services.telegram-bots.instances.
{ config, lib, pkgs, env, inputs, gws, system, bun2nix, ... }:
let
  cfg = config.my.services.telegram-bots;
  telegramBotsPackage =
    inputs.telegram-bots.packages.${pkgs.stdenv.hostPlatform.system}.default;

  runnableModule = {
    options = {
      package = lib.mkOption {
        type = lib.types.package;
        description = "Executable (typically writeShellScriptBin / writeShellApplication).";
      };
      timeoutSec = lib.mkOption {
        type = lib.types.ints.positive;
        default = 60;
        description = "Kill the process group after this many seconds.";
      };
      env = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Extra environment for this runner only.";
      };
    };
  };

  commandModule = {
    options = {
      description = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "setMyCommands / help text.";
      };
      aliases = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Alternate slash names (e.g. calendar for cal).";
      };
      package = lib.mkOption {
        type = lib.types.package;
        description = "Executable for this slash command.";
      };
      timeoutSec = lib.mkOption {
        type = lib.types.ints.positive;
        default = 60;
      };
      env = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
      };
    };
  };

  instanceModule = { name, ... }: {
    options = {
      enable = lib.mkEnableOption "telegram-bots instance ${name}";

      token-secret = lib.mkOption {
        type = lib.types.str;
        default = "${name}_telegram_bot_token";
        defaultText = lib.literalExpression "\"\${name}_telegram_bot_token\"";
        description = "sops secret name holding the Bot API token.";
      };

      chat-ids = lib.mkOption {
        type = lib.types.listOf lib.types.int;
        default = [ ];
        description = "Outbound notify/ask chat ids (first is primary).";
      };

      allowed-user-ids = lib.mkOption {
        type = lib.types.listOf lib.types.int;
        default = [ ];
        description = "Users allowed to answer asks / run commands. Empty = any.";
      };

      allowed-chat-ids = lib.mkOption {
        type = lib.types.listOf lib.types.int;
        default = [ ];
        description = "Inbound chat allowlist. Empty = all chats.";
      };

      guest-mode = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Handle BotFather guest mentions.";
      };

      timezone = lib.mkOption {
        type = lib.types.str;
        default = "UTC";
      };

      context = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Opaque JSON for command runners (TELEGRAM_BOTS_CONTEXT).";
      };

      features.builtinHelp = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Auto-handle /help from command descriptions.";
      };

      defaultCommand = lib.mkOption {
        type = lib.types.nullOr (lib.types.submodule runnableModule);
        default = null;
        description = "Optional runner for free-form messages (no leading /).";
      };

      commands = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule commandModule);
        default = { };
        description = "Slash commands (key = primary name, no leading /).";
      };

      extraEnvironment = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Extra environment variables for the daemon unit.";
      };
    };
  };

  enabledInstances = lib.filterAttrs (_: inst: inst.enable) cfg.instances;

  brownFamEnabled =
    lib.attrByPath [ "instances" "brown-fam" "enable" ] false cfg;

  brownFamScripts =
    if env.platform == "linux" then
      pkgs.callPackage ./telegram-bots/_brown-fam.nix
        {
          expensesSpreadsheet = lib.getExe'
            (pkgs.callPackage ../programs/bun-scripts.linux/_package.nix {
              inherit bun2nix;
            }) "expenses-spreadsheet";
          gwsExe = lib.getExe gws.packages.${system}.default;
          cursorAgentExe = lib.getExe config.my.programs.cursor.agent.package;
          telegramBotsExe = lib.getExe cfg.package;
          credentialsFile = "${env.home}/Sync/secrets/google/gws_credentials.json";
        }
    else
      { };
in
{
  imports = [
    (lib.mkRemovedOptionModule [ "my" "services" "agent-telegram-bot" ] ''
      Use my.services.telegram-bots.instances.<name> instead
      (e.g. instances.agent with chat-ids / allowed-user-ids / token-secret).
    '')
    (lib.mkRemovedOptionModule [ "my" "services" "fam-telegram-bot" ] ''
      Family guest bot is my.services.telegram-bots.instances.brown-fam
      (guest-mode, token-secret = "fam_telegram_bot_token", Nix command scripts).
    '')
    (lib.mkRemovedOptionModule [ "my" "services" "telegram-bot" ] ''
      Use my.services.telegram-bots.instances.brown-fam instead.
    '')
  ];

  options.my.services.telegram-bots = {
    package = lib.mkOption {
      type = lib.types.package;
      default = telegramBotsPackage;
      defaultText = lib.literalExpression "inputs.telegram-bots.packages.\${pkgs.stdenv.hostPlatform.system}.default";
      description = "telegram-bots package.";
    };

    instances = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule instanceModule);
      default = { };
      description = ''
        Telegram bot instances. Attr key is the instance id for
        `telegram-bots --instance <name> notify|ask|ping`.
      '';
    };

    brownFamScripts = lib.mkOption {
      type = lib.types.attrsOf lib.types.package;
      readOnly = true;
      description = ''
        Packages for instances.brown-fam commands / defaultCommand
        (expense, task, cal, default).
      '';
    };
  };

  config = lib.mkMerge [
    {
      my.services.telegram-bots.brownFamScripts = brownFamScripts;
    }
    (lib.mkIf (enabledInstances != { }) (env.selectPlatform {
      linux = {
        assertions = lib.optionals brownFamEnabled [
          {
            assertion = config.my.programs.gws.enable;
            message = "my.services.telegram-bots.instances.brown-fam.enable requires my.programs.gws.enable.";
          }
          {
            assertion = config.my.programs.cursor.agent.enable;
            message = "my.services.telegram-bots.instances.brown-fam.enable requires my.programs.cursor.agent.enable.";
          }
        ];

        sops.secrets = lib.mapAttrs'
          (name: inst:
            lib.nameValuePair inst.token-secret {
              owner = env.user;
              group = "secrets";
              mode = "0440";
            }
          )
          enabledInstances;

        users.users.${env.user}.linger = true;

        environment.systemPackages = [ cfg.package ];

        home-manager.users.${env.user} = {
          imports = [ inputs.telegram-bots.homeManagerModules.default ];

          services.telegram-bots = {
            package = cfg.package;
            instances = lib.mapAttrs
              (name: inst: {
                enable = true;
                tokenFile = config.sops.secrets.${inst.token-secret}.path;
                chatIds = inst.chat-ids;
                allowedUserIds = inst.allowed-user-ids;
                allowedChatIds = inst.allowed-chat-ids;
                guestMode = inst.guest-mode;
                timezone = inst.timezone;
                context = inst.context;
                features.builtinHelp = inst.features.builtinHelp;
                extraEnvironment = inst.extraEnvironment;
                defaultCommand = inst.defaultCommand;
                commands = inst.commands;
              })
              enabledInstances;
          };
        };
      };
    }))
  ];
}
