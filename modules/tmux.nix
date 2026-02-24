_:
{
  programs.tmux = {
    enable = true;
    keyMode = "vi";

    extraConfig = ''
      # Custom keybinds for splitting
      bind-key -n C-M-= split-window -h
      bind-key -n C-M-- split-window -v
    '';
  };
}
