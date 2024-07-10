# Hyprland module for system level configuration.
# See: https://www.youtube.com/watch?v=zt3hgSBs11g

{ pkgs, inputs, ... }:
let
  startupScript = pkgs.pkgs.writeShellScriptBin "start" ''
    ${pkgs.waybar}/bin/waybar &
    ${pkgs.swww}/bin/swww init &
    ${pkgs.dunst}/bin/dunst &
    ${pkgs.kitty}/bin/kitty &

    sleep 1
  '';
  # ${pkgs.rofi-wayland}/bin/rofi -show drun -show-icons &
  # ${pkgs.guake}/bin/guake &
  # ${pkgs.swww}/bin/swww img ${./wallpaper.png} &
  gamemodeScript = pkgs.pkgs.writeShellScriptBin "start" ''
    HYPRGAMEMODE=$(hyprctl getoption animations:enabled | awk 'NR==1{print $2}')
    if [ "$HYPRGAMEMODE" = 1 ] ; then
        hyprctl --batch "\
            keyword animations:enabled 0;\
            keyword decoration:drop_shadow 0;\
            keyword decoration:blur:enabled 0;\
            keyword general:gaps_in 0;\
            keyword general:gaps_out 0;\
            keyword general:border_size 1;\
            keyword decoration:rounding 0"
        exit
    fi
    hyprctl reload
  '';
  hyprPkgs = inputs.hyprland.packages."${pkgs.system}";
  hyprPlugins = inputs.hyprland-plugins.packages."${pkgs.system}";
in
{
  # Enable cachix for hyprland, otherwise hyprland will be built from source:
  nix.settings = {
    substituters = [ "https://hyprland.cachix.org" ];
    trusted-public-keys = [ "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" ];
  };

  environment = {
    sessionVariables = {
      GUAKE_ENABLE_WAYLAND = 1;
    };
    systemPackages = with pkgs; [
      # pyprland
      hyprpicker
      hyprcursor
      hyprlock
      hypridle
      # hyprpaper
      kitty
      rofi-wayland
      waybar
      dunst
      swww

      networkmanager
      networkmanagerapplet # Provides `nmi-connection-editor` command
    ];
  };

  programs = {
    hyprland = {
      enable = true;
      package = hyprPkgs.hyprland;
    };
    waybar = {
      enable = true;
    };
  };

  xdg.portal = {
    enable = true;
    # extraPortals = [
    #   hyprPkgs.xdg-desktop
    # ];
  };

  home-manager.users.dano = {
    wayland.windowManager.hyprland = {
      enable = true;
      package = hyprPkgs.hyprland;
      # systemd.variables = ["--all"];

      plugins = [
        hyprPlugins.borders-plus-plus
      ];

      settings = {
        exec-once = ''${startupScript}/bin/start'';

        "$mod" = "SUPER";
        bind = [
          "$mod, S, exec, rofi -show drun -show-icons"
          "alt, F4, killactive"
          "$mod, Q, exec, kitty"
          "$mod, F10, exec, ${gamemodeScript}/bin/start"
          # "$mod, Q, exec, guake-toggle"
        ]
        ++ (
          # workspaces
          # binds $mod + [shift +] {1..10} to [move to] workspace {1..10}
          builtins.concatLists (builtins.genList
            (
              x:
              let
                ws =
                  let
                    c = (x + 1) / 10;
                  in
                  builtins.toString (x + 1 - (c * 10));
              in
              [
                "$mod, ${ws}, workspace, ${toString (x + 1)}"
                "$mod SHIFT, ${ws}, movetoworkspace, ${toString (x + 1)}"
              ]
            )
            10)
        );

        # TODO: This monitor is specific to the tiny laptop, will need to move this to that specific config.
        monitor = "eDP-1, 1920x1200, 0x0, 1.0";

        input = {
          natural_scroll = true;
          touchpad = {
            natural_scroll = true;
          };
        };

        # "plugin:borders-plus-plus" = {
        #   add_borders = 1; # 0 - 9

        #   # you can add up to 9 borders
        #   "col.border_1" = "rgb(ffffff)";
        #   "col.border_2" = "rgb(2222ff)";

        #   # -1 means "default" as in the one defined in general:border_size
        #   border_size_1 = 10;
        #   border_size_2 = -1;

        #   # makes outer edges match rounding of the parent. Turn on / off to better understand. Default = on.
        #   natural_rounding = "yes";
        # };
      };
    };
  };
}
