# The way this is setup with greetd is not fully secure. It's possible somebody could bypass the lock screen.
{ env, ... }: {
  security.pam.services.hyprlock = { }; # Required for hyprlock to work
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
          after_sleep_cmd = "hyprctl dispatch dpms on && hyprlock --immediate";
          ignore_dbus_inhibit = false;
          lock_cmd = "hyprlock";
        };
        listener = [
          {
            # 5 minutes of idle and put hyprlock on
            timeout = 300;
            on-timeout = "hyprlock";
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
            on-timeout = "hyprctl dispatch dpms off && systemctl suspend";
            on-resume = "hyprctl dispatch dpms on";
          }
        ];
      };
    };
  };
}
