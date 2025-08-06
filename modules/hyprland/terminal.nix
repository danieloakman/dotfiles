{ env, ... }: {
  home-manager.users.${env.user} = {
    wayland.windowManager.hyprland = {
      settings = {
        "$term" = "kitty";

        exec-once = [
          # Start a terminal in a special workspace.
          "[workspace special silent] $term"
          # "[workspace pass silent] $term -- passs -c"
        ];

        bind = [
          "CTRL, grave, togglespecialworkspace, special"
          # "$mod, Q, togglespecialworkspace, pass"
        ];

        animations = {
          animation = [
            "specialWorkspace, 1, 4, default, slidevert"
          ];
        };

        input = {
          # Allow clicking around the terminal in its special workspace.
          special_fallthrough = true;
        };
      };
    };
  };
}

