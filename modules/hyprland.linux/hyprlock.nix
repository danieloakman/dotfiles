# Hyprlock as greeter: greetd auto-logs into Hyprland, then exec-once runs
# hyprlock as the password gate. Not fully secure — the lock screen can be bypassed.
{ env, lib, config, ... }:
{
  options.my.desktop.hyprland.hyprlock.enable = lib.mkEnableOption "Enable the Hyprlock lockscreen";

  config = lib.mkIf config.my.desktop.hyprland.hyprlock.enable {
    assertions = [
      {
        assertion = config.my.desktop.hyprland.enable;
        message = "Hyprlock requires Hyprland to be enabled";
      }
    ];

    # Auto-login so hyprlock (exec-once below) is the login UI.
    my.desktop.hyprland.auto-login = true;

    security.pam.services = {
      hyprlock = {
        # Unlock the GNOME keyring when the lock screen is unlocked
        enableGnomeKeyring = true;
      };
      # Also ensure greetd participates in keyring unlock (useful when a password is entered)
      greetd.enableGnomeKeyring = true;
    };
    programs.hyprlock.enable = true; # Keep package available system-wide

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
    };
  };
}
