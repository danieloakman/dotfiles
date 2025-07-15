{ env, ... }: {
  security.pam.services.hyprlock = { }; # Required for hyprlock to work
  programs.hyprlock.enable = true;

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
          after_sleep_cmd = "hyprctl dispatch dpms on";
          ignore_dbus_inhibit = false;
          lock_cmd = "hyprlock";
        };
        listener = [
          {
            timeout = 900;
            on-timeout = "hyprlock";
          }
          {
            timeout = 1200;
            on-timeout = "hyprctl dispatch dpms off";
            on-resume = "hyprctl dispatch dpms on";
          }
        ];
      };
    };
  };
}
