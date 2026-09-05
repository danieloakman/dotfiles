{ pkgs, env, lib, config, ... }: {
  options.my.desktop.hyprland.onscreen-keyboard.enable = lib.mkEnableOption "Enable the wvkbd-mobintl Wayland on-screen keyboard";

  config = lib.mkIf config.my.desktop.hyprland.onscreen-keyboard.enable {
    assertions = [
      {
        assertion = config.my.desktop.hyprland.enable;
        message = "wvkbd-mobintl requires Hyprland to be enabled";
      }
    ];

    environment.systemPackages = with pkgs; [
      wvkbd # Wayland on-screen keyboard
    ];

    home-manager.users.${env.user} = { lib, ... }:
      let
        hl = import ./_lua-lib.nix { inherit lib; };
      in
      {
        programs.zsh.shellAliases = {
          onscreen-keyboard-toggle = "kill -34 $(ps -C wvkbd-mobintl)";
        };

        wayland.windowManager.hyprland = {
          plugins = [
            # Enable Hyprgrass for binding keys to the on-screen keyboard
            # inputs.hyprgrass.packages.${pkgs.system}.default
            # optional integration with pulse-audio, see examples/hyprgrass-pulse/README.md
            # inputs.hyprgrass.packages.${pkgs.system}.hyprgrass-pulse
          ];

          settings = {
            on = [
              (hl.onStart [ "wvkbd-mobintl --hidden" ])
            ];

            bind = [
              (hl.bind (hl.keyShift "S") (hl.exec "onscreen-keyboard-toggle"))
            ];
          };
        };
      };
  };
}
