# The way this is setup with greetd is not fully secure. It's possible somebody could bypass the lock screen.
{ env, pkgs, lib, ... }:
let
  hypridleStatus = (pkgs.writeShellScriptBin "hypridle-status" ''
    if systemctl --user is-active --quiet hypridle.service; then
      echo "enabled"
    else
      echo "disabled"
    fi
  '');
  hypridleStart = (pkgs.writeShellScriptBin "hypridle-start" ''
    systemctl --user start hypridle.service
    echo "enabled"
  '');
  hypridleStop = (pkgs.writeShellScriptBin "hypridle-stop" ''
    systemctl --user stop hypridle.service
    echo "disabled"
  '');
  hypridleToggle = (pkgs.writeShellScriptBin "hypridle-toggle" ''
    STATUS=$(${lib.getExe hypridleStatus})
    if [ "$STATUS" = "enabled" ]; then
      ${lib.getExe hypridleStop}
    else
      ${lib.getExe hypridleStart}
    fi
  '');
in
{
  security.pam.services = {
    hyprlock = {
      # Unlock the GNOME keyring when the lock screen is unlocked
      enableGnomeKeyring = true;
    };
    # Also ensure greetd participates in keyring unlock (useful when a password is entered)
    greetd.enableGnomeKeyring = true;
  };
  programs.hyprlock.enable = true; # Keep package available system-wide

  services.greetd = {
    enable = true;
    settings = rec {
      initial_session = {
        command = "hyprland > /dev/null 2>&1";
        inherit (env) user;
      };
      default_session = initial_session;
    };
  };

  environment.systemPackages = [
    hypridleStatus
    hypridleToggle
    hypridleStart
    hypridleStop
  ];

  home-manager.users.${env.user} = {
    # Didn't end up looking that good, so just use default hyprlock config instead.
    /* programs.hyprlock = {
      enable = true;
      # Configure hyprlock appearance via Home Manager
      settings = {
        # Simple blurred screenshot background
        # background = [
        #   {
        #     path = "screenshot";
        #     blur_passes = 2;
        #     blur_size = 7;
        #   }
        # ];

        # Centered password input field (no layout label shown)
        # input-field = [
        #   {
        #     size = "400, 90";
        #     outline_thickness = 4;
        #     dots_size = 0.25;
        #     dots_spacing = 0.15;
        #     dots_center = true;
        #     fade_on_empty = true;
        #     placeholder_text = "<i>Password…</i>";
        #     position = "0, 0";
        #     halign = "center";
        #     valign = "center";
        #   }
        # ];

        # 12-hour time above the input field
        label = [
          {
            text = "$TIME12";
            # font_size = 48;
            # # position = "0, -120";
            # halign = "center";
            # valign = "center";
          }
        ];
      };
    }; */
    wayland.windowManager.hyprland = {
      settings.exec-once = [
        "hyprlock || hyprctl dispatch exit"
      ];
    };

    services.hypridle = {
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
