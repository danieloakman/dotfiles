# Guest-mode Telegram bot for the couple DM.
#
# The bot is not a member of the chat. A mention (@bot …) arrives as a
# guest_message; answerGuestQuery posts the confirmation into that DM.
# A private chat with the bot is a normal message. Confirm runs gws.
# Slash commands parse locally. Anything else goes through the interpreter,
# which is cursor-agent today and replaceable behind the same request type.
# Create the bot in @BotFather, enable Guest Mode, and put its token in sops
# as telegram_bot_token before turning this on.
{ config, lib, pkgs, env, gws, system, ... }:
let
  cfg = config.my.services.telegram-bot;
in
{
  options.my.services.telegram-bot = {
    enable = lib.mkEnableOption ''
      Long-poll a Telegram bot. Private chats and guest mentions get a
      confirmation, and a Confirm tap appends an expense, inserts a calendar
      event, or adds a task through gws.
      Requires the sops secret telegram_bot_token, Guest Mode in BotFather,
      and my.programs.cursor.agent.enable.
    '';

    spreadsheet-id = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Expenses spreadsheet id. Each confirmed expense appends
        date, card, amount, payer, note. Empty disables expense writes.
      '';
    };

    sheet-range = lib.mkOption {
      type = lib.types.str;
      default = "Expenses!A1";
      description = "A1 range passed to `gws sheets +append`. The tab must already exist.";
    };

    payer = lib.mkOption {
      type = lib.types.str;
      default = "Dan";
      description = "Payer written into the expense row.";
    };

    calendar-id = lib.mkOption {
      type = lib.types.str;
      default = "primary";
      description = "Google Calendar id for /cal.";
    };

    tasklist = lib.mkOption {
      type = lib.types.str;
      default = "@default";
      description = "Google Tasks list id for /task.";
    };

    timezone = lib.mkOption {
      type = lib.types.str;
      default = "Australia/Sydney";
      description = "IANA timezone for expense dates and /cal times.";
    };

    allowed-chat-ids = lib.mkOption {
      type = lib.types.listOf lib.types.int;
      default = [ ];
      description = ''
        Telegram chat ids that may summon the bot. Empty allows every chat.
        The journal logs chat_id on each mention.
      '';
    };

    allowed-user-ids = lib.mkOption {
      type = lib.types.listOf lib.types.int;
      default = [ ];
      description = ''
        Telegram user ids that may summon the bot. Empty allows every user.
        The journal logs user_id on each mention.
      '';
    };

    interpreter.workspace = lib.mkOption {
      type = lib.types.str;
      default = "${env.home}/repos/personal/dotfiles";
      description = ''
        Workspace passed to the interpreter. The current interpreter is
        cursor-agent; a later provider can replace that binary.
      '';
    };
  };

  config = lib.mkIf cfg.enable (env.selectPlatform {
    linux =
      let
        telegramBot = pkgs.callPackage ./telegram-bot/_package.nix { };
        gwsExe = lib.getExe gws.packages.${system}.default;
        cursorAgentExe = lib.getExe config.my.programs.cursor.agent.package;
        settings = pkgs.writeText "telegram-bot-settings.json" (builtins.toJSON {
          inherit (cfg) payer tasklist timezone;
          spreadsheetId = cfg.spreadsheet-id;
          sheetRange = cfg.sheet-range;
          calendarId = cfg.calendar-id;
          allowedChatIds = cfg.allowed-chat-ids;
          allowedUserIds = cfg.allowed-user-ids;
          workspace = cfg.interpreter.workspace;
        });
        tokenPath = config.sops.secrets.telegram_bot_token.path;
      in
      {
        assertions = [
          {
            assertion = config.my.programs.gws.enable;
            message = "my.services.telegram-bot.enable requires my.programs.gws.enable.";
          }
          {
            assertion = config.my.programs.cursor.agent.enable;
            message = "my.services.telegram-bot.enable requires my.programs.cursor.agent.enable.";
          }
        ];

        sops.secrets.telegram_bot_token = {
          owner = env.user;
          group = "secrets";
          mode = "0440";
        };

        users.users.${env.user}.linger = true;

        home-manager.users.${env.user}.systemd.user.services.telegram-bot = {
          Unit = {
            Description = "Telegram guest bot for couple-chat admin";
            After = [ "network-online.target" ];
          };
          Service = {
            ExecStart = lib.getExe telegramBot;
            Restart = "on-failure";
            RestartSec = 5;
            StateDirectory = "telegram-bot";
            Environment = [
              "TELEGRAM_BOT_TOKEN_FILE=${tokenPath}"
              "TELEGRAM_BOT_SETTINGS=${settings}"
              "GWS=${gwsExe}"
              "CURSOR_AGENT=${cursorAgentExe}"
              "GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE=${env.home}/Sync/secrets/google/gws_credentials.json"
            ];
          };
          Install.WantedBy = [ "default.target" ];
        };
      };
  });
}
