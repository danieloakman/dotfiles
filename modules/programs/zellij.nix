{ env, config, lib, ... }:
let
  cfg = config.my.programs.zellij;
in
{
  options.my.programs.zellij = {
    enable = lib.mkEnableOption "Enable and configure Zellij.";

    autoStart = {
      enable = lib.mkEnableOption ''
        Automatically start Zellij in every interactive zsh session.

        Uses Home Manager's Zellij shell integration. Skips nested sessions when
        `$ZELLIJ` is already set.
      '';

      attachExistingSession = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          When autostarting, attach to the default session if one already exists
          instead of creating a new session.
        '';
      };

      exitShellOnExit = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Exit the shell (and typically the terminal tab) when the Zellij session ends.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${env.user} = {
      programs.zellij = {
        enable = true;
        enableZshIntegration = true;
        attachExistingSession = cfg.autoStart.attachExistingSession;
        exitShellOnExit = cfg.autoStart.exitShellOnExit;
        extraConfig = ''
          keybinds {
            normal {
              bind "Ctrl Alt =" { NewPane "Right"; SwitchToMode "normal"; }
              bind "Ctrl Alt -" { NewPane "Down"; SwitchToMode "normal"; }
            }
          }
        '';
      };
    };
  };
}
