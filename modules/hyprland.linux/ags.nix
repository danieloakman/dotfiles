# Dotfiles glue for github:danieloakman/ags-desktop-shell.
#
# Companion Hyprland enablement and binds stay here; the packaged app + AGS HM
# wiring live in the upstream homeManagerModules.default.
{ env, inputs, pkgs, lib, config, ... }:
let
  cfgEnabled = config.my.desktop.ui-shell == "ags";
  agsDesktopShell =
    inputs.ags-desktop-shell.packages.${pkgs.stdenv.hostPlatform.system}.default;
  passwordStoreDir = "${env.home}/repos/personal/pwd-store";
in
{
  config = lib.mkIf cfgEnabled {
    assertions = [
      {
        assertion = config.my.desktop.hyprland.enable;
        message = "AGS requires Hyprland to be enabled";
      }
    ];

    my.desktop.hyprland = {
      blueman.enable = true;
      hyprlock.enable = true;
      hypridle.enable = true;
      sway-utils = {
        enable = true;
        notifications.enable = true;
        volume.enable = true;
        brightness.enable = true;
        caps-lock.enable = true;
        playerctl.enable = true;
      };
    };

    services.gvfs.enable = true; # Caches network cover art for mpris with spotify usage

    home-manager.users.${env.user} = { lib, ... }:
      let
        hl = import ./_lua-lib.nix { inherit lib; };
      in
      {
        imports = [ inputs.ags-desktop-shell.homeManagerModules.default ];

        programs.ags-desktop-shell = {
          enable = true;
          inherit passwordStoreDir;
        };

        wayland.windowManager.hyprland = {
          settings = {
            on = [
              (hl.onStart [ (lib.getExe agsDesktopShell) ])
            ];

            bind = [
              (hl.bind (hl.key "Q") (hl.exec "ags request toggle password-search"))
              # Open app launcher. TODO: use the AGS app launcher instead.
              (hl.bind (hl.key "space") (hl.exec "rofi -show combi -combi-modi \"window,drun\" -modi combi -show-icons"))
              (hl.bind (hl.key "S") (hl.exec "rofi-google-search"))
            ];
          };
        };

        programs.cava.enable = true; # Audio visualizer

        xdg.desktopEntries = {
          shutdown = {
            name = "Shutdown";
            exec = "shutdown -P now";
            categories = [ "System" ];
            icon = "system-shutdown";
            startupNotify = true;
          };
          reboot = {
            name = "Reboot";
            exec = "reboot";
            categories = [ "System" ];
            icon = "system-reboot";
            startupNotify = true;
          };
          suspend = {
            name = "Suspend";
            exec = "systemctl suspend";
            categories = [ "System" ];
            icon = "preferences-system";
            startupNotify = true;
          };
          logout = {
            name = "Logout";
            exec = "logout";
            categories = [ "System" ];
            icon = "system-log-out";
            startupNotify = true;
          };
        };
      };
  };
}
