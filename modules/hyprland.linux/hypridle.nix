{ env, pkgs, lib, config, ... }:
let
  hypridleStatus = pkgs.writeShellScriptBin "hypridle-status" ''
    if systemctl --user is-active --quiet hypridle.service; then
      echo "enabled"
    else
      echo "disabled"
    fi
  '';
  hypridleStart = pkgs.writeShellScriptBin "hypridle-start" ''
    systemctl --user start hypridle.service
    echo "enabled"
  '';
  hypridleStop = pkgs.writeShellScriptBin "hypridle-stop" ''
    systemctl --user stop hypridle.service
    echo "disabled"
  '';
  hypridleToggle = pkgs.writeShellScriptBin "hypridle-toggle" ''
    STATUS=$(${lib.getExe hypridleStatus})
    if [ "$STATUS" = "enabled" ]; then
      ${lib.getExe hypridleStop}
    else
      ${lib.getExe hypridleStart}
    fi
  '';
in
{
  options.my.services.hypridle.enable = lib.mkEnableOption "Enable Hypridle (idle daemon: dim, lock, DPMS, suspend)";

  config = lib.mkIf config.my.services.hypridle.enable {
    assertions = [
      {
        assertion = config.my.desktop.hyprland.enable;
        message = "Hypridle requires Hyprland to be enabled";
      }
      {
        assertion = config.my.services.hyprlock.enable;
        message = "Hypridle requires Hyprlock (lock_cmd uses hyprlock)";
      }
    ];

    environment.systemPackages = [
      hypridleStatus
      hypridleToggle
      hypridleStart
      hypridleStop
    ];

    home-manager.users.${env.user}.services.hypridle = {
      enable = true;
      settings = {
        general = {
          before_sleep_cmd = "loginctl lock-session"; # Lock before suspending
          after_sleep_cmd = "hyprctl dispatch dpms on";
          ignore_dbus_inhibit = false;
          lock_cmd = "pidof hyprlock || hyprlock"; # Avoid starting hyprlock multiple times
        };
        listener = [
          {
            timeout = 270; # 4.5 minutes of idle and lower brightness
            on-timeout = "notify-send \"Idle for 4:30 minutes\" \"About to lock the session due to inactivity\" -u critical -i emblem-important-symbolic -e | brightnessctl -s set 5%"; # Lower brightness and save previous brightness state to file
            on-resume = "brightnessctl -r"; # Restore previous brightness state
          }
          {
            # 5 minutes of idle and put hyprlock on
            timeout = 300;
            on-timeout = "loginctl lock-session";
          }
          {
            # 10 minutes of idle and turn screen off
            timeout = 600;
            on-timeout = "hyprctl dispatch dpms off";
            on-resume = "hyprctl dispatch dpms on";
          }
          {
            # 15 minutes of idle and suspend
            timeout = 900;
            on-timeout = "systemctl suspend";
          }
        ];
      };
    };
  };
}
