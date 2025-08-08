# The way this is setup with greetd is not fully secure. It's possible somebody could bypass the lock screen.
{ env, ... }: {
  security.pam.services = {
    hyprlock = {
      # Unlock the GNOME keyring when the lock screen is unlocked
      enableGnomeKeyring = true;
    };
    # Also ensure greetd participates in keyring unlock (useful when a password is entered)
    greetd.enableGnomeKeyring = true;
  };
  programs.hyprlock.enable = true; # TODO: customise hyprlock a bit. Make the clock 12h for example

  services.greetd = {
    enable = true;
    settings = rec {
      initial_session = {
        command = "hyprland > /dev/null 2>&1";
        user = env.user;
      };
      default_session = initial_session;
    };
  };

  home-manager.users.${env.user} = {
    wayland.windowManager.hyprland = {
      settings = {
        exec-once = [
          "hyprlock || hyprctl dispatch exit"
        ];
      };
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
            on-timeout = "brightnessctl -s set 5%"; # Lower brightness and save previous brightness state to file
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
