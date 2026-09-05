{ env, lib, config, ... }:
let
  cfg = config.my.desktop.hyprland.sway-utils;
in
{
  options.my.desktop.hyprland.sway-utils = {
    enable = lib.mkEnableOption "Enable the Sway utils";
    notifications.enable = lib.mkEnableOption "Enable the Sway notifications";
    volume.enable = lib.mkEnableOption "Enable the Sway volume OSD for keyboard volume keys";
    brightness.enable = lib.mkEnableOption "Enable the Sway brightness OSD for keyboard brightness keys";
    caps-lock.enable = lib.mkEnableOption "Enable the Sway caps lock OSD for keyboard caps lock keys";
    playerctl.enable = lib.mkEnableOption "Enable the Sway playerctl OSD for keyboard playerctl keys";
    num-lock.enable = lib.mkEnableOption "Enable the Sway num lock OSD for keyboard num lock keys";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${env.user} = { lib, ... }:
      let
        hl = import ./_lua-lib.nix { inherit lib; };
      in
      {
        services = {
          # Don't need these anymore if we're using AGS and its custom notification backend.
          swaync = lib.mkIf cfg.notifications.enable {
            enable = true; # Notification daemon
            settings = {
              # positionX = "center";
              # positionY = "top";
              # layer = "overlay";
              # control-center-layer = "top";
              # layer-shell = true;
              # cssPriority = "application";
              # control-center-margin-top = 0;
              # control-center-margin-bottom = 0;
              # control-center-margin-right = 0;
              # control-center-margin-left = 0;
              # notification-2fa-action = true;
              # notification-inline-replies = false;
              # notification-icon-size = 64;
              # notification-body-image-height = 100;
              # notification-body-image-width = 200;
            };
          };
          swayosd = {
            enable = true;
          };
        };

        wayland.windowManager.hyprland.settings.bind = lib.mkMerge [
          (lib.mkIf cfg.brightness.enable [
            (hl.bindl "XF86MonBrightnessUp" (hl.exec "swayosd-client --brightness 5"))
            (hl.bindl "XF86MonBrightnessDown" (hl.exec "swayosd-client --brightness -5"))
          ])
          (lib.mkIf cfg.volume.enable [
            (hl.bindl "XF86AudioRaiseVolume" (hl.exec "swayosd-client --output-volume 2"))
            (hl.bindl "XF86AudioLowerVolume" (hl.exec "swayosd-client --output-volume -2"))
          ])
          (lib.mkIf cfg.caps-lock.enable [
            (hl.bindl "ALT + F7" (hl.exec "swayosd-client --output-volume 2"))
            (hl.bindl "ALT + F6" (hl.exec "swayosd-client --output-volume -2"))
            (hl.bindr "CAPS + Caps_Lock" (hl.exec "swayosd-client --caps-lock"))
          ])
          (lib.mkIf cfg.playerctl.enable [
            (hl.bindl "XF86AudioMicMute" (hl.exec "swayosd-client --input-volume mute-toggle"))
            (hl.bindl "XF86AudioMute" (hl.exec "swayosd-client --output-volume mute-toggle"))
            (hl.bindl "XF86AudioPlay" (hl.exec "swayosd-client --playerctl play-pause"))
            (hl.bindl "XF86AudioPrev" (hl.exec "swayosd-client --playerctl prev"))
            (hl.bindl "XF86AudioNext" (hl.exec "swayosd-client --playerctl next"))
          ])
          # (lib.mkIf cfg.num-lock.enable [
          #   (hl.bindr "NUM + Num_Lock" (hl.exec "swayosd-client --num-lock"))
          # ])
        ];
      };
  };
}
