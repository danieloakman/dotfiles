# Hyprland module for system level configuration.
# See: https://www.youtube.com/watch?v=zt3hgSBs11g

{ pkgs, inputs, env, ... }:
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
        # hyprPlugins.borders-plus-plus
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

          "SUPER_SHIFT, right, movetoworkspace, +1"
          "SUPER_SHIFT, left, movetoworkspace, -1"
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

        binds = {
          workspace_back_and_forth = true;
          allow_workspace_cycles = true;
          pass_mouse_when_bound = false;
        };

        monitor = env.hyprland.monitor;

        input = {
          natural_scroll = true;

          kb_layout = "us";
          # kb_variant =
          # kb_model =
          # kb_options =
          # kb_rules =
          repeat_rate = 50;
          repeat_delay = 300;
          numlock_by_default = true;
          left_handed = false;
          follow_mouse = true;
          float_switch_override_focus = false;

          touchpad = {
            disable_while_typing = true;
            natural_scroll = true; # Was false from dots' config
            clickfinger_behavior = false;
            middle_button_emulation = true;
            tap-to-click = true;
            drag_lock = false;
          };

          # below for devices with touchdevice ie. touchscreen
          # TODO: set up env for touch device
          # touchdevice = {
          #   enabled = true;
          # };

          # below is for table see link above for proper variables
          # TODO: Set up env for tablet 
          # tablet = {
          #   transform = 0;
          #   left_handed = 0;
          # };
        };

        gestures = {
          workspace_swipe = true;
          workspace_swipe_fingers = 3;
          workspace_swipe_distance = 500;
          workspace_swipe_invert = true;
          workspace_swipe_min_speed_to_force = 30;
          workspace_swipe_cancel_ratio = 0.5;
          workspace_swipe_create_new = true;
          workspace_swipe_forever = true;
          #workspace_swipe_use_r = true #uncomment if wanted a forever create a new workspace with swipe right
        };

        # Could help when scaling and not pixelating
        xwayland = {
          force_zero_scaling = true;
        };

        # cursor section for Hyprland >= v0.41.0
        # cursor = {
        #   no_hardware_cursors = false;
        #   enable_hyprcursor = true;
        #   warp_on_change_workspace = true; # for -git or Hyprland >v0.41.1
        # };

        group = {
          col.border_active = "$color15";

          groupbar = {
            col.active = "$color0";
          };
        };

        misc = {
          disable_hyprland_logo = true;
          disable_splash_rendering = true;
          middle_click_paste = false;

          # Don't know what these do:
          vfr = true;
          #vrr = 0
          mouse_move_enables_dpms = true;
          enable_swallow = true;
          swallow_regex = "^(kitty)$";
          focus_on_activate = false;
          no_direct_scanout = true; # for fullscreen games
          initial_workspace_tracking = 0;
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
