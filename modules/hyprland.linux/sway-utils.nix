{ env, lib, config, ... }:
let
  cfg = config.my.programs.swayUtils;
in
{
  options.my.programs.swayUtils = {
    enable = lib.mkEnableOption "Enable the Sway utils";
    notifications.enable = lib.mkEnableOption "Enable the Sway notifications";
    volume.enable = lib.mkEnableOption "Enable the Sway volume OSD for keyboard volume keys";
    brightness.enable = lib.mkEnableOption "Enable the Sway brightness OSD for keyboard brightness keys";
    capsLock.enable = lib.mkEnableOption "Enable the Sway caps lock OSD for keyboard caps lock keys";
    playerctl.enable = lib.mkEnableOption "Enable the Sway playerctl OSD for keyboard playerctl keys";
    numLock.enable = lib.mkEnableOption "Enable the Sway num lock OSD for keyboard num lock keys";
  };

  config = lib.mkIf cfg.enable ({
    home-manager.users.${env.user} = {
      services = {
        # Don't need these anymore if we're using AGS and its custom notification backend.
        swaync = lib.mkIf cfg.notifications.enable ({
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
        });
        swayosd = {
          enable = true;
        };
      };

      wayland.windowManager.hyprland.settings = {
        # `l` flag denotes these will also work when an input inhibitor is active
        bindl = lib.mkMerge [
          (lib.mkIf cfg.brightness.enable [
            ", XF86MonBrightnessUp, exec, swayosd-client --brightness 5"
            ", XF86MonBrightnessDown, exec, swayosd-client --brightness -5"
          ])
          (lib.mkIf cfg.volume.enable [
            ", XF86AudioRaiseVolume, exec, swayosd-client --output-volume 2"
            ", XF86AudioLowerVolume, exec, swayosd-client --output-volume -2"
          ])
          (lib.mkIf cfg.capsLock.enable [
            "alt, F7, exec, swayosd-client --output-volume 2" # Need these because XF86 volume keys don't work sometimes
            "alt, F6, exec, swayosd-client --output-volume -2"
          ])
          (lib.mkIf cfg.playerctl.enable [
            ", XF86AudioMicMute, exec, swayosd-client --input-volume mute-toggle"
            ", XF86AudioMute, exec, swayosd-client --output-volume mute-toggle"
            ", XF86AudioPlay, exec, swayosd-client --playerctl play-pause"
            ", XF86AudioPrev, exec, swayosd-client --playerctl prev"
            ", XF86AudioNext, exec, swayosd-client --playerctl next"
          ])
        ];
        bindr = lib.mkMerge [
          (lib.mkIf cfg.capsLock.enable [
            "CAPS, Caps_Lock, exec, swayosd-client --caps-lock"
          ])
          (lib.mkIf cfg.numLock.enable [
            # "NUM, Num_Lock, exec, swayosd-client --num-lock" # TODO: fix this
          ])
        ];
      };
    };
  });
}
