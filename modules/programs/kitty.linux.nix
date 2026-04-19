{ env, lib, config, ... }:
let
  cfg = config.my.programs.kitty;
in
{
  options.my.programs.kitty.enable = lib.mkEnableOption "Enable the Kitty terminal emulator";

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      home-manager.users.${env.user} = {
        programs = {
          kitty = {
            enable = true;
            keybindings = {
              "ctrl+c" = "copy_or_interrupt";
              "shift+alt+=" = "launch --location=vsplit";
              "shift+alt+-" = "launch --location=hsplit";
            };
            settings = {
              enabled_layouts = "splits";
              background_opacity = lib.mkForce 0.5; # between 0.0 and 1.0
              background_blur = lib.mkForce 1; # Set to a positive value to enable background blur
            };
          };
        };
      };
    }
    (lib.mkIf config.my.desktop.hyprland.enable {
      home-manager.users.${env.user} = {
        wayland.windowManager.hyprland = {
          settings = {
            "$term" = "kitty";

            exec-once = [
              # Start a terminal in a special workspace.
              "[workspace special silent] $term"
              # "[workspace pass silent] $term -- passs -c"
            ];

            bind = [
              "$mod, return, exec, $term"
              "$mod, grave, togglespecialworkspace, special"
              # "$mod, Q, togglespecialworkspace, pass"
            ];

            animations = {
              animation = [
                "specialWorkspace, 1, 4, default, slidevert"
              ];
            };

            input = {
              # Allow clicking around the terminal in its special workspace.
              special_fallthrough = true;
            };
          };
        };
      };
    })
  ]);
}
