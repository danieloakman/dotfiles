{ env, config, lib, ... }:
let
  cfg = config.my.programs.tmux;
in
{
  options.my.programs.tmux.enable = lib.mkEnableOption "Enable and configure tmux.";

  config = lib.mkIf cfg.enable (env.selectPlatform {
    any.programs.tmux = {
      enable = true;

      extraConfig = ''
        # Custom keybinds for splitting
        bind-key -n C-M-= split-window -h
        bind-key -n C-M-- split-window -v
      '';
    };
    linux.programs.tmux = {
      keyMode = "vi";
    };
    darwin.programs.tmux = {
      enableVim = true;
    };
  });
}
