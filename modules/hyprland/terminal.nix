{ env, ... }: {
  home-manager.users.${env.user} = {
    wayland.windowManager.hyprland = {
      settings = {
        "$term" = "kitty";

        exec-once = [
          "[workspace special silent] $term"
        ];

        bind = [
          "$mod, Q, exec, zsh -c \"source ~/.zshrc && $term -- passs -c\""
          "CTRL, grave, togglespecialworkspace, special"
        ];

        animations = {
          animation = [
            "specialWorkspace, 1, 4, default, slidevert, top"
          ];
        };
      };
    };

    programs = {
      kitty = {
        enable = true;
        keybindings = {
          "ctrl+c" = "copy_or_interrupt";
          "shift+alt+=" = "launch --location=hsplit";
          "shift+alt+-" = "launch --location=vsplit";
        };
        settings = { };
      };
    };
  };
}

