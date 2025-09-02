{ env, ... }: {
  home-manager.users.${env.user} = {
    wayland.windowManager.hyprland = {
      settings = {
        exec-once = [
          "qs"
        ];
      };
    };

    programs.quickshell = {
      enable = true;
      systemd.enable = true;
      activeConfig = "shell.qml";
      configs = {
        "shell.qml" = ./shell.qml;
      };
    };
  };
}
