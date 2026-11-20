# Dotfiles glue for telegram-bots (evolved from agent-telegram-bot).
#
# Host values and sops stay here; systemd units live in upstream
# homeManagerModules.default → services.telegram-bots.instances.
{ config, lib, pkgs, env, inputs, ... }:
let
  cfg = config.my.services.telegram-bots;
  telegramBotsPackage =
    inputs.telegram-bots.packages.${pkgs.stdenv.hostPlatform.system}.default;

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
        description = "Opaque JSON for command runners.";
      };

      # Full command / interpreter wiring stays on the upstream HM module for now;
      # glue can grow these later when brown-fam migrates off fam-telegram-bot.
    };
  };

  enabledInstances = lib.filterAttrs (_: inst: inst.enable) cfg.instances;
in
{
  imports = [
    (lib.mkRemovedOptionModule [ "my" "services" "agent-telegram-bot" ] ''
      Use my.services.telegram-bots.instances.<name> instead
      (e.g. instances.agent with chat-ids / allowed-user-ids / token-secret).
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
  };

  config = lib.mkIf (enabledInstances != { }) (env.selectPlatform {
    linux = {
      sops.secrets = lib.mapAttrs' (name: inst:
        lib.nameValuePair inst.token-secret {
          owner = env.user;
          group = "secrets";
          mode = "0440";
        }
      ) enabledInstances;

      users.users.${env.user}.linger = true;

      environment.systemPackages = [ cfg.package ];

      home-manager.users.${env.user} = {
        imports = [ inputs.telegram-bots.homeManagerModules.default ];

        services.telegram-bots = {
          package = cfg.package;
          instances = lib.mapAttrs (name: inst: {
            enable = true;
            tokenFile = config.sops.secrets.${inst.token-secret}.path;
            chatIds = inst.chat-ids;
            allowedUserIds = inst.allowed-user-ids;
            allowedChatIds = inst.allowed-chat-ids;
            guestMode = inst.guest-mode;
            timezone = inst.timezone;
            context = inst.context;
          }) enabledInstances;
        };
      };
    };
  });
}
