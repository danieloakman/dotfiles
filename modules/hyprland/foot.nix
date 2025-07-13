{ env, ... }: {
  home-manager.users.${env.user} = {
    wayland.windowManager.hyprland = {
      settings = {
        exec-once = [
          "[workspace special silent] foot"
        ];
        bind = [
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
      foot = {
        enable = true;
        settings = {
          main = {
            font = "Fira Code:size=11";
            dpi-aware = "yes";
          };
        };
      };
    };
  };
}
