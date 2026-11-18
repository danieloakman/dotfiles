# Multipurpose Telegram bridge for agents: notify (send) and ask (blocking reply).
#
# Long-poll daemon + unix control socket. CLI:
#   agent-telegram-bot send --role vuln-monitor "…"
#   agent-telegram-bot ask  --role vuln-monitor --timeout 600 "…"
#
# Package comes from github:danieloakman/agent-telegram-bot.
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
      assertions = [
        {
          assertion = cfg.chat-ids != [ ];
          message = "my.services.agent-telegram-bot.chat-ids must be non-empty.";
        }
      ];

      sops.secrets.agent_telegram_bot_token = {
        owner = env.user;
        group = "secrets";
        mode = "0440";
      };

      users.users.${env.user}.linger = true;

      environment.systemPackages = [ cfg.package ];

      home-manager.users.${env.user} = {
        home.packages = [ cfg.package ];

        systemd.user.services.agent-telegram-bot = {
          Unit = {
            Description = "Agent Telegram bridge (notify + ask)";
            After = [ "network-online.target" ];
          };
          Service = {
            ExecStart = "${lib.getExe cfg.package} daemon";
            Restart = "on-failure";
            RestartSec = 5;
            StateDirectory = "agent-telegram-bot";
            Environment = [
              "AGENT_TELEGRAM_BOT_TOKEN_FILE=${config.sops.secrets.agent_telegram_bot_token.path}"
              "AGENT_TELEGRAM_BOT_SETTINGS=${
                pkgs.writeText "agent-telegram-bot-settings.json" (builtins.toJSON {
                  chatIds = cfg.chat-ids;
                  allowedUserIds = cfg.allowed-user-ids;
                })
              }"
            ];
          };
          Install.WantedBy = [ "default.target" ];
        };
      };
    };
  });
}
