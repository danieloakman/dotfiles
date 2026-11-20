# Dotfiles glue for github:danieloakman/agent-telegram-bot.
#
# Host values (chat-ids, allowed-user-ids) and sops stay here; the systemd user
# unit and HM options live in the upstream homeManagerModules.default.
#
# Separate from fam-telegram-bot (couple expenses/calendar guest bot).
{ config, lib, pkgs, env, inputs, ... }:
let
  cfg = config.my.services.agent-telegram-bot;
  agentTelegramBotPackage =
    inputs.agent-telegram-bot.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  options.my.services.agent-telegram-bot = {
    enable = lib.mkEnableOption ''
      Run the agent Telegram bridge (notify + ask). Requires sops secret
      agent_telegram_bot_token and a private chat with the bot.
    '';

    chat-ids = lib.mkOption {
      type = lib.types.listOf lib.types.int;
      default = [ ];
      example = [ 8348310754 ];
      description = ''
        Destination Telegram chat ids for send/ask (usually your private chat
        with the bot). First id is used for outbound messages.
      '';
    };

    allowed-user-ids = lib.mkOption {
      type = lib.types.listOf lib.types.int;
      default = [ ];
      description = ''
        Telegram user ids allowed to answer asks. Empty allows any user in the
        configured chats.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = agentTelegramBotPackage;
      defaultText = lib.literalExpression "inputs.agent-telegram-bot.packages.\${pkgs.stdenv.hostPlatform.system}.default";
      description = "agent-telegram-bot package.";
    };
  };

  config = lib.mkIf cfg.enable (env.selectPlatform {
    linux = {
      sops.secrets.agent_telegram_bot_token = {
        owner = env.user;
        group = "secrets";
        mode = "0440";
      };

      users.users.${env.user}.linger = true;

      environment.systemPackages = [ cfg.package ];

      home-manager.users.${env.user} = {
        imports = [ inputs.agent-telegram-bot.homeManagerModules.default ];

        services.agent-telegram-bot = {
          enable = true;
          inherit (cfg) package;
          chatIds = cfg.chat-ids;
          allowedUserIds = cfg.allowed-user-ids;
          tokenFile = config.sops.secrets.agent_telegram_bot_token.path;
        };
      };
    };
  });
}
