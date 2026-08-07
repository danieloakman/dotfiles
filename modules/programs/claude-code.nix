{ env, config, lib, pkgs, ... }:
let
  cfg = config.my.programs.claude-code;
  jsonFormat = pkgs.formats.json { };

  # System policy only — Claude never writes here. Keep runtime prefs (effortLevel, theme, …) out.
  managedSettingsFile = jsonFormat.generate "claude-code-managed-settings.json" (
    cfg.managed-settings
    // {
      "$schema" = "https://json.schemastore.org/claude-code-settings.json";
    }
  );
in
{
  options.my.programs.claude-code = {
    enable = lib.mkEnableOption "Enable and configure Claude Code.";

    managed-settings = lib.mkOption {
      inherit (jsonFormat) type;
      default = { };
      description = ''
        Claude Code managed-settings.json (system policy). Merged across modules into
        `/etc/claude-code/managed-settings.json` (Linux) or
        `/Library/Application Support/ClaudeCode/managed-settings.json` (Darwin).
        Do not put user runtime prefs here — those belong in `~/.claude/settings.json`.
      '';
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      my.programs.claude-code.managed-settings = {
        # Avoid telemetry 404s when using claude-local (ANTHROPIC_BASE_URL → local llama-server).
        env.CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
        includeCoAuthoredBy = false;
      };

      home-manager.users.${env.user} = {
        programs.claude-code = {
          enable = true;
          # Always enable so rules/skills install; Homebrew supplies the binary on Darwin
          # (npm registry is blocked there).
          package = lib.mkIf (env.platform == "darwin") null;
        };

        # Never manage user settings via HM (EROFS /effort). Policy is managed-settings only.
        home.file."${env.home}/.claude/settings.json".enable = lib.mkForce false;
      };
    }

    (env.selectPlatform {
      linux = {
        environment.etc."claude-code/managed-settings.json".source = managedSettingsFile;
      };
      # Claude on macOS ignores /etc/claude-code; only this path counts as managed settings.
      darwin = {
        system.activationScripts.extraActivation.text = lib.mkAfter ''
          mkdir -p "/Library/Application Support/ClaudeCode"
          ln -sfn ${managedSettingsFile} "/Library/Application Support/ClaudeCode/managed-settings.json"
        '';
      };
    })
  ]);
}
