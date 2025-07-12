# Hyprland module for system level configuration.
# See: https://www.youtube.com/watch?v=zt3hgSBs11g

{ pkgs, inputs, env, ... }:
let
  startupScript = pkgs.pkgs.writeShellScriptBin "start" ''
    ${pkgs.waybar}/bin/waybar &
    ${pkgs.swww}/bin/swww init &
    ${pkgs.dunst}/bin/dunst &
    ${pkgs.pyprland}/bin/pypr &

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
      pyprland
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
        "$files" = "thunar";
        "$term" = "kitty";

        bind = [
          "$mod, space, exec, rofi -show drun -show-icons"
          "$mod, S, exec, rofi-google-search"
          "$mod, K, exec, kill-processes"
          "$mod, Q, exec, zsh -c \"source ~/.zshrc && $term -- passs -c\""
          "alt, F4, killactive"
          "$mod, F10, exec, ${gamemodeScript}/bin/start"
          "CTRL, grave, exec, pypr toggle $term"
          "$mod, T, exec, $files"

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
          special_scale_factor = 0.8;
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
    programs = {
      waybar = {
        enable = true;
        settings = {
          mainBar = {
            layer = "top";
            position = "top";
            height = 30;
            spacing = 4;
            margin = "6";

            modules-left = [ "hyprland/workspaces" ];
            modules-center = [ "hyprland/window" ];
            modules-right = [
              "network"
              "cpu"
              "memory"
              "temperature"
              "battery"
              "clock"
              "tray"
            ];

            "hyprland/workspaces" = {
              disable-scroll = true;
              all-outputs = true;
              warp-on-scroll = false;
              format = "{name}";
              on-click = "activate";
              sort-by-number = true;
            };

            "hyprland/window" = {
              format = "{}";
              separate-outputs = false;
            };

            network = {
              format-wifi = "  {essid} {signalStrength}%";
              format-ethernet = "  {ifname}";
              format-disconnected = "  Disconnected";
              format-linked = "  {ifname}";
              max-length = 50;
              tooltip-format = "{ifname} via {gwaddr}";
              tooltip-format-wifi = "{essid} ({signalStrength}%)
IP: {ipaddr}";
              tooltip-format-ethernet = "{ifname}
IP: {ipaddr}";
              tooltip-format-disconnected = "Disconnected";
              on-click = "nm-connection-editor";
            };

            cpu = {
              interval = 1;
              format = "  {usage}%";
              max-length = 10;
              tooltip = true;
              tooltip-format = "CPU: {usage}%";
              on-click = "";
              on-click-middle = "";
              on-click-right = "";
            };

            memory = {
              interval = 1;
              format = "  {percentage}%";
              max-length = 10;
              tooltip = true;
              tooltip-format = "Memory: {used:0.1f}GiB / {total:0.1f}GiB ({percentage}%)";
              on-click = "";
              on-click-middle = "";
              on-click-right = "";
            };

            temperature = {
              hwmon-path-abs = "/sys/class/hwmon/hwmon2/temp1_input";
              input-filename = "temp1_input";
              interval = 1;
              format = "  {temperatureC}°C";
              max-length = 10;
              tooltip = true;
              tooltip-format = "Temperature: {temperatureC}°C";
              on-click = "";
              on-click-middle = "";
              on-click-right = "";
            };

            battery = {
              bat = "BAT0";
              interval = 30;
              states = {
                warning = 20;
                critical = 10;
              };
              format = "  {capacity}% {timeTo}";
              format-charging = "  {capacity}% {timeTo}";
              format-plugged = "  {capacity}%";
              format-alt = "{capacity}%";
              format-full = "  {capacity}%";
              format-icons = [ "" "" "" "" "" ];
              max-length = 25;
              tooltip = true;
              tooltip-format = "{capacity}% {timeTo}";
              on-click = "";
              on-click-middle = "";
              on-click-right = "";
            };

            clock = {
              timezone = "Australia/Sydney";
              tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
              format-alt = "{:%Y-%m-%d %I:%M %p}";
              format = "  {:%I:%M %p}";
              max-length = 25;
              interval = 1;
              format-calendar = "<span color='#ecc6d0'><b>{}</b></span>";
              format-calendar-weeks = "<span color='#99ccdd'><b>W{:%U}</b></span>";
              format-calendar-weekdays = "<span color='#ff6699'><b>{}</b></span>";
              on-click = "";
              on-click-middle = "";
              on-click-right = "";
            };

            tray = {
              icon-size = 21;
              spacing = 10;
            };
          };
        };
        style = ''
          * {
            border: none;
            border-radius: 0;
            font-family: "JetBrainsMono Nerd Font", "Font Awesome 6 Free Solid", "Font Awesome 6 Brands", "Font Awesome 6 Free", "Roboto", "Helvetica Neue", "Liberation Sans", "Arial", sans-serif;
            font-size: 13px;
            font-style: normal;
            font-weight: normal;
            min-height: 0;
          }

          window#waybar {
            background-color: rgba(43, 48, 59, 0.5);
            border-bottom: 3px solid rgba(100, 114, 125, 0.5);
            color: #ffffff;
            transition-property: background-color;
            transition-duration: .5s;
          }

          window#waybar.hidden {
            opacity: 0.2;
          }

          window#waybar.termite {
            background-color: #3F3F3F;
          }

          window#waybar.chromium {
            background-color: #000000;
            border: none;
          }

          #workspaces button {
            padding: 0 5px;
            background-color: transparent;
            color: #ffffff;
            border-bottom: 3px solid transparent;
          }

          #workspaces button:hover {
            background: rgba(0, 0, 0, 0.2);
            box-shadow: inherit;
            border-bottom: 3px solid #ffffff;
          }

          #workspaces button.active {
            background-color: #64727D;
            border-bottom: 3px solid #ffffff;
          }

          #workspaces button.urgent {
            background-color: #eb4d4b;
          }

          #mode {
            background-color: #64727D;
            border-bottom: 3px solid #ffffff;
          }

          #clock,
          #battery,
          #cpu,
          #memory,
          #disk,
          #temperature,
          #backlight,
          #network,
          #pulseaudio,
          #custom-media,
          #tray,
          #mode,
          #idle_inhibitor,
          #mpd {
            padding: 0 10px;
            margin: 0 4px;
            color: #ffffff;
          }

          #clock {
            background-color: #64727D;
          }

          #battery {
            background-color: #ffffff;
            color: #000000;
          }

          #battery.charging, #battery.plugged {
            color: #ffffff;
            background-color: #26A65B;
            animation-name: blink;
            animation-duration: 0.5s;
            animation-timing-function: linear;
            animation-iteration-count: infinite;
            animation-direction: alternate;
          }

          @keyframes blink {
            to {
              background-color: #ffffff;
              color: #000000;
            }
          }

          #battery.critical:not(.charging) {
            background-color: #f53c3c;
            color: #ffffff;
            animation-name: blink;
            animation-duration: 0.5s;
            animation-timing-function: linear;
            animation-iteration-count: infinite;
            animation-direction: alternate;
          }

          label:focus {
            background-color: #000000;
          }

          #cpu {
            background-color: #2ecc71;
            color: #000000;
          }

          #memory {
            background-color: #9b59b6;
          }

          #disk {
            background-color: #964B00;
          }

          #network {
            background-color: #2980b9;
          }

          #network.disconnected {
            background-color: #f53c3c;
          }

          #pulseaudio {
            background-color: #f1c40f;
            color: #000000;
          }

          #pulseaudio.muted {
            background-color: #90b1b6;
          }

          #custom-media {
            background-color: #66cc99;
            color: #2a5f45;
            min-width: 100px;
          }

          #custom-media.custom-spotify {
            background-color: #66cc99;
          }

          #custom-media.custom-vlc {
            background-color: #ffa000;
          }

          #temperature {
            background-color: #f0932b;
          }

          #temperature.critical {
            background-color: #eb4d4b;
          }

          #tray {
            background-color: #2980b9;
          }

          #tray > .passive {
            -gtk-icon-effect: dim;
          }

          #tray > .needs-attention {
            -gtk-icon-effect: highlight;
            background-color: #eb4d4b;
          }

          #idle_inhibitor {
            background-color: #2d3436;
          }

          #idle_inhibitor.activated {
            background-color: #ecf0f1;
            color: #2d3436;
          }

          #mpd {
            background-color: #66cc99;
            color: #2a5f45;
          }

          #mpd.disconnected {
            background-color: #f53c3c;
          }

          #mpd.stopped {
            background-color: #90b1b6;
          }

          #mpd.paused {
            background-color: #51a37a;
          }

          #language {
            background: #00b093;
            color: #740864;
            padding: 0 5px;
            margin: 0 5px;
            min-width: 16px;
          }

          #keyboard-state {
            background: #97e1ad;
            color: #000000;
            padding: 0 0px;
            margin: 0 5px;
            min-width: 16px;
          }

          #keyboard-state > label {
            padding: 0 5px;
          }

          #keyboard-state > label.locked {
            background: rgba(0, 0, 0, 0.2);
          }

          #scratchpad {
            background: rgba(0, 150, 136, 0.8);
          }

          #scratchpad.empty {
            background-color: transparent;
          }
        '';
      };
    };
  };
}
