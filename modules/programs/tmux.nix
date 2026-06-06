{ env, config, lib, ... }:
let
  cfg = config.my.programs.tmux;
in
{
  options.my.programs.tmux.enable = lib.mkEnableOption "Enable and configure tmux.";

  config = lib.mkIf cfg.enable {
    home-manager.users.${env.user} = {
      programs.tmux = {
        enable = true;
        keyMode = "vi";
        extraConfig = ''
          # Custom keybinds for splitting
          bind-key -n C-M-= split-window -h
          bind-key -n C-M-- split-window -v
        '';
      };
    };
  };
}
