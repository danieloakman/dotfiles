{ env, lib, config, ... }:
let
  cfgEnabled = config.my.desktop.uiShell == "quickshell";
in
{
  config = lib.mkIf cfgEnabled {
    assertions = [
      {
        assertion = config.my.desktop.hyprland.enable;
        message = "Quickshell can only be enabled if Hyprland is enabled";
      }
    ];

    # No dedicated greeter; passwordless greetd auto-login into Hyprland.
    my.desktop.hyprland.autoLogin = true;
    my.services.stylix.enable = true;

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
  };
}
