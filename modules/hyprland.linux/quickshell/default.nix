{ env, lib, config, ... }: {

  options.my.programs.quickshell.enable = lib.mkEnableOption "Enable the Quickshell desktop shell for Hyprland";

  config = lib.mkIf config.my.programs.quickshell.enable ({
    assertions = [
      {
        assertion = config.my.desktop.hyprland.enable;
        message = "Quickshell can only be enabled if Hyprland is enabled";
      }
    ];

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
  });
}
