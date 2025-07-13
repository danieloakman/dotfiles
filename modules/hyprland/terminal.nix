{ env, ... }: {
  home-manager.users.${env.user} = {
    wayland.windowManager.hyprland = {
      settings = {
        "$term" = "kitty";

        exec-once = [
          "[workspace special silent] $term"
          # "[workspace pass silent] $term -- passs -c"
        ];

        bind = [
          # "$mod, Q, togglespecialworkspace, pass"
          "CTRL, grave, togglespecialworkspace, special"
        ];

        animations = {
          animation = [
            "specialWorkspace, 1, 4, default, slidevert"
          ];
        };
      };
    };

    programs = {
      kitty = {
        enable = true;
        keybindings = {
          "ctrl+c" = "copy_or_interrupt";
          "shift+alt+=" = "launch --location=vsplit";
          "shift+alt+-" = "launch --location=hsplit";
        };
        settings = { };
      };
    };
  };
}

