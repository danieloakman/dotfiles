# Hyprland module for system level configuration.
# See: https://www.youtube.com/watch?v=zt3hgSBs11g

{ pkgs, inputs, env, config, ... }:
let
  startupScript = pkgs.pkgs.writeShellScriptBin "start" ''
    ${pkgs.waybar}/bin/waybar &
    ${pkgs.pyprland}/bin/pypr &
    ${pkgs.kitty}/bin/kitty &

    sleep 1
  '';
  # ${pkgs.guake}/bin/guake &
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
  imports = [
    ./bluetooth.nix
    ./lockscreen.nix
    ./terminal.nix
    ./waybar.nix
  ];

  environment = {
    sessionVariables = { };
    systemPackages = with pkgs; [
      pyprland # Extra Hyprland utils/tools
      hyprpicker # Color picker
      hyprcursor # Cursor
      rofi-wayland # Make sure it's installed, even though we have imported rofi.nix
      hyprshot # Screenshot tool
      brightnessctl # Control backlight brightness
      libnotify # Adds notification commands like `notify-send`
      wev # Wayland event viewer. Useful for finding uncommon key codes

      networkmanager
      networkmanagerapplet # Provides `nmi-connection-editor` command
      xfce.thunar # File explorer
    ];
  };

  programs = {
    hyprland = {
      enable = true;
      package = hyprPkgs.hyprland;
    };
  };

  xdg.portal = {
    enable = true;
    # extraPortals = [
    #   hyprPkgs.xdg-desktop
    # ];
  };

  home-manager.users.${env.user} = {
    wayland.windowManager.hyprland = {
      enable = true;
      package = hyprPkgs.hyprland;
      # systemd.variables = ["--all"];

      plugins = [
        # hyprPlugins.borders-plus-plus
      ];

      settings = {
        # Keep this a list, so other nix modules can add to it.
        exec-once = [
          ''${startupScript}/bin/start''
        ];

        "$mod" = "SUPER";
        "$files" = "thunar";

        # `l` flag denotes these will also work when an input inhibitor is active
        bindl = [
          ", XF86MonBrightnessUp, exec, brightnessctl set +5%"
          ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
          ", XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
          ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
          ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
          "alt, F7, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+" # Need these because XF86 volume keys don't work
          "alt, F6, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
          ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
          ", XF86AudioPlay, exec, playerctl play-pause"
          ", XF86AudioPrev, exec, playerctl previous"
          ", XF86AudioNext, exec, playerctl next"
        ];

        bind = [
          "$mod, space, exec, rofi -show combi -combi-modi \"window,drun,run\" -modi combi -show-icons"
          "$mod, S, exec, rofi-google-search"
          "$mod, K, exec, kill-processes"
          "$mod, return, exec, $term"
          "alt, F4, killactive"
          "$mod, C, killactive"
          "$mod, V, togglefloating"
          "$mod, F10, exec, ${gamemodeScript}/bin/start"
          "$mod, T, exec, $files"
          ", Print, exec, hyprshot -o ~/Pictures/Screenshots -m region"
          "$mod, P, exec, hyprpicker -a"

          # Move focus between windows:
          "$mod, left, movefocus, l"
          "$mod, h, movefocus, l"
          "$mod, right, movefocus, r"
          "$mod, l, movefocus, r"
          "$mod, up, movefocus, u"
          "$mod, k, movefocus, u"
          "$mod, down, movefocus, d"
          "$mod, j, movefocus, d"

          # Move windows between workspaces:
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

        dwindle = {
          pseudotile = true;
          preserve_split = true;
          special_scale_factor = 0.95;
        };

        master = {
          new_status = "master";
          new_on_top = 1;
          mfact = 0.5;
        };

        general = {
          # Does not exist now:
          # sensitivity = 1.00;
          # apply_sens_to_raw = 1;

          border_size = 2;
          gaps_in = 6;
          gaps_out = 8;

          resize_on_border = true;

          # col.active_border = $color12;
          # col.inactive_border = $backgroundCol;

          layout = "dwindle";
        };

        decoration = {
          rounding = 10;

          active_opacity = 1.0;
          inactive_opacity = 0.9;
          fullscreen_opacity = 1.0;

          dim_inactive = true;
          dim_strength = 0.1;
          dim_special = 0.8;

          # Does not exist now:
          # drop_shadow = true;
          # shadow_range = 6;
          # shadow_render_power = 1;
          # col.shadow = $color12;
          # col.shadow_inactive = "0x50000000";

          blur = {
            enabled = true;
            size = 6;
            passes = 2;
            ignore_opacity = true;
            new_optimizations = true;
            special = true;
          };
        };


        animations = {
          enabled = true;

          bezier = [
            "wind, 0.05, 0.9, 0.1, 1.05"
            "winIn, 0.1, 1.1, 0.1, 1.1"
            "winOut, 0.3, -0.3, 0, 1"
            "liner, 1, 1, 1, 1"
          ];

          animation = [
            "windows, 1, 6, wind, slide"
            "windowsIn, 1, 6, winIn, slide"
            "windowsOut, 1, 5, winOut, slide"
            "windowsMove, 1, 5, wind, slide"
            "border, 1, 1, liner"
            "borderangle, 1, 180, liner, loop" #used by rainbow borders and rotating colors
            "fade, 1, 10, default"
            "workspaces, 1, 5, wind"
          ];
        };

        binds = {
          workspace_back_and_forth = true;
          allow_workspace_cycles = true;
          pass_mouse_when_bound = false;
        };

        # Window rules
        windowrule = [
          "workspace 1, class:^(vivaldi)$"
          "workspace 2, class:^(Cursor)$"
          "workspace 2, class:^(code)$"
          "workspace 3, class:^(Spotify)$"
          "workspace 4, class:^(obsidian)$"
          "workspace 5, class:^(Discord)$"
          "workspace 6, class:^(Steam)$"
        ];

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
          # TODO: tweak these to make it easier to use with trackpad
          workspace_swipe = true;
          workspace_swipe_fingers = 3;
          workspace_swipe_distance = 500;
          workspace_swipe_invert = true;
          workspace_swipe_min_speed_to_force = 30;
          workspace_swipe_cancel_ratio = 0.33;
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

        # TODO:
        # group = {
        #   col.border_active = "$color15";

        #   groupbar = {
        #     col.active = "$color0";
        #   };
        # };

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
          # no_direct_scanout = true; # for fullscreen games. Does not exist anymore
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

    home = {
      file = {
        ".config/hypr/pyprland.toml".text = ''
          [pyprland]
          terminal = "kitty"
        '';
      };
    };

    services = {
      hyprpaper = {
        enable = true;
        settings =
          let
            wallpaperPath = "/home/dano/repos/personal/dotfiles/files/assets/${config.networking.hostName}-wallpaper.jpeg";
          in
          {
            ipc = "on";
            splash = false;
            splash_offset = 2.0;
            preload = [ wallpaperPath ];
            # TODO: this will need to be moved to the host root config, as the monitor name is not known here.
            wallpaper = [ "eDP-1,${wallpaperPath}" ];
          };
      };

      swaync.enable = true; # Notification daemon
      playerctld.enable = true; # Media player control daemon
      swayosd = { # TODO: This is supposed to popup with volume changes and other notifications like that but isn't?
        enable = true;
        display = "eDP-1";
      };
    };
  };
}
