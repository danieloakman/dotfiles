{ inputs, pkgs, env, lib, ... }: {
  environment.systemPackages = with pkgs; [
    wvkbd # Wayland on-screen keyboard
  ];

  home-manager.users.${env.user} = {
    programs.zsh.shellAliases = {
      onscreen-keyboard-toggle = "kill -34 $(ps -C wvkbd-mobintl)";
    };

    wayland.windowManager.hyprland = {
      plugins = [
        # Enable Hyprgrass for binding keys to the on-screen keyboard
        inputs.hyprgrass.packages.${pkgs.system}.default
        # optional integration with pulse-audio, see examples/hyprgrass-pulse/README.md
        # inputs.hyprgrass.packages.${pkgs.system}.hyprgrass-pulse
      ];

      settings = {
        exec-once = [
          "wvkbd-mobintl --hidden" # Init the on-screen keyboard
        ];
      };

      # Guard plugin-specific keywords to prevent errors during initial parse
      extraConfig = lib.mkAfter ''
        # hyprlang noerror true
        hyprgrass-bind = , edge:d:u, exec, onscreen-keyboard-toggle
        # hyprlang noerror false
      '';
    };
  };
}
