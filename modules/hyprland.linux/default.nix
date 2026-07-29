# Hyprland module for system level configuration.
# See: https://www.youtube.com/watch?v=zt3hgSBs11g

{ pkgs, env, lib, inputs, config, ... }:
let
  cfg = config.my.desktop.hyprland;
  hyprlandPkg = inputs.hyprland.legacyPackages.${pkgs.stdenv.hostPlatform.system}.hyprland;
  monitorConnector = monitor: lib.head (lib.splitString "," monitor);
  wallpaperPath = lib.optionalString (cfg.hyprpaper.wallpaper != null) (toString cfg.hyprpaper.wallpaper);
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
  screenSaveScript = pkgs.pkgs.writeShellScriptBin "screen-save" ''
    mouse_move_enables_dpms=$(hyprctl getoption misc:mouse_move_enables_dpms | awk 'NR==1{print $2}')
    if [ "$mouse_move_enables_dpms" = 1 ] ; then
      hyprctl keyword misc:mouse_move_enables_dpms 0
      hyprctl dispatch dpms off
    else
      hyprctl keyword misc:mouse_move_enables_dpms 1
      hyprctl dispatch dpms on
    fi
  '';
  # hyprPkgs = inputs.hyprland.packages."${pkgs.system}";
  # hyprPlugins = inputs.hyprland-plugins.packages."${pkgs.system}";
  vivaldiExe = lib.getExe pkgs.vivaldi;
in
{
  options.my.desktop = {
    # Under desktop (not hyprland) so shells can be reused with other compositors (e.g. Niri).
    uiShell = lib.mkOption {
      type = lib.types.enum [ "ags" "noctalia" "noctalia-v5" "quickshell" "waybar" null ];
      default = null;
      description = "The UI shell to use for the desktop environment.";
    };
  };

  options.my.desktop.hyprland = {
    enable = lib.mkEnableOption "Enable the Hyprland desktop environment.";

    monitors = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Per-machine Hyprland monitor lines (`settings.monitor`), e.g.
        `"DP-1, 1920x1080, 0x0, 1.0"`.
      '';
    };

    workspaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Optional workspace-to-monitor bindings (`settings.workspace`), e.g.
        `"1, monitor:DP-1"`.
      '';
    };

    windowRules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Optional Hyprland window rules (`settings.windowrule`).";
    };

    hyprpaper = {
      wallpaper = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Wallpaper image for hyprpaper on all configured monitors.";
      };
    };

    autoLogin = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Passwordless greetd auto-login into Hyprland. Greeter modules opt into
        the pattern they need: hyprlock sets this true (lock screen is the
        gate after auto-login); noctalia-v5 greeter leaves it false and owns
        the greetd session instead.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.monitors != [ ];
        message = "my.desktop.hyprland.monitors must be set when Hyprland is enabled.";
      }
      {
        assertion = cfg.hyprpaper.wallpaper != null;
        message = "my.desktop.hyprland.hyprpaper.wallpaper must be set when Hyprland is enabled.";
      }
    ];
    my = {
      programs = {
        kitty.enable = true;
        ydotool.enable = true;
        rofi.enable = true;
        hyprshot.enable = true;
        webapps = {
          YouTube.url = "https://www.youtube.com";
          Twitch.url = "https://www.twitch.tv";
          Reddit.url = "https://www.reddit.com";
          "Instagram Chats".url = "https://www.instagram.com/direct/inbox/";
          "Claude AI".url = "https://claude.ai/chat";
          "Gemini AI".url = "https://gemini.google.com";
          "Google Drive".url = "https://drive.google.com";
          Gmail.url = "https://mail.google.com";
          "Google Calendar".url = "https://calendar.google.com";
          "NixOS Search Packages".url = "https://search.nixos.org/packages?channel=unstable";
          "NixOS Home Manager Configuration Search".url =
            "https://home-manager-options.extranix.com/?query=&release=master";
          "Google Taskboard".url = "https://tasksboard.com/app";
          "Google Photos".url = "https://photos.google.com";
          "Google Mobile Messages".url = "https://messages.google.com/web/conversations";
          "Disney Plus".url = "https://www.disneyplus.com";
          Netflix.url = "https://www.netflix.com";
          Stan.url = "https://www.stan.com.au";
          "Amazon Prime".url = "https://www.primevideo.com/";
          Audible.url = "https://www.audible.com.au/library";
        };
      };
      # Haven't found a need for this again:
      services.pyprland.enable = false;
    };

    environment = {
      sessionVariables = {
        NIXOS_OZONE_WL = "1";
      };
      systemPackages = with pkgs; [
        hyprpicker # Color picker
        # hyprcursor # Cursor. Stylix seems to handle cursors on wayland, so don't need this.
        rofi # Make sure it's installed, even though we have imported rofi.nix
        brightnessctl # Control backlight brightness
        libnotify # Adds notification commands like `notify-send`
        wev # Wayland event viewer. Useful for finding uncommon key codes
        uwsm # Universal Wayland session manager.
        rofi-network-manager # Rofi network manager GUI
        nautilus # File explorer
        gnome-disk-utility # Gnome disk utility for formatting drives
        baobab # Gnome utility for analysing disk usage
      ];
    };

    programs = {
      hyprland = {
        enable = true;
        package = hyprlandPkg;
      };
      seahorse.enable = true; # optional GUI tool for Gnome keyring
    };

    # TODO: see if we can disable this in favour of gpg-home.linux.ni
    # Enable GNOME Keyring so applications can store and retrieve secrets.
    services.gnome.gnome-keyring.enable = true;

    xdg.portal = {
      enable = true;
      # extraPortals = [
      #   hyprPkgs.xdg-desktop
      # ];
    };

    home-manager.users.${env.user} = {
      wayland.windowManager.hyprland = {
        enable = true;
        package = hyprlandPkg;
        configType = "hyprlang";
        # systemd.variables = ["--all"];

        # plugins = [
        #   # hyprPlugins.borders-plus-plus
        # ];

        settings = {
          monitor = cfg.monitors;
          workspace = cfg.workspaces;
          windowrule = cfg.windowRules;

          "$mod" = "SUPER";
          "$files" = "nautilus";
          "$browser" = "uwsm app -- ${vivaldiExe} --ozone-platform=wayland";
          "$webapp" = "$browser --app";

          bindm = [
            # mouse movements
            "$mod, mouse:272, movewindow"
            "$mod, mouse:273, resizewindow"
          ];

          bind = [
            "$mod, K, exec, rofi-kill-processes"
            # "$mod, Q, exec, rofi-pass"
            "alt, F4, killactive"
            "$mod, C, killactive"
            "$mod, V, togglefloating"
            "$mod, F10, exec, ${lib.getExe gamemodeScript}"
            "$mod, F9, exec, ${lib.getExe screenSaveScript}" # Toggle turning display off and on
            "$mod, T, exec, $files"
            "$mod, P, exec, hyprpicker -a"
            # "$mod, Q, exec, zsh -c 'passmenu'" # No longer needed as we have AGS based password search
            "$mod, B, exec, $browser"

            # Opted to use desktop entries instead of this.
            # Open webapps:
            # "SUPER_SHIFT, Y, exec, $webapp=\"https://www.youtube.com\""

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

          input = {
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
              natural_scroll = true;
              clickfinger_behavior = false;
              middle_button_emulation = true;
              tap-to-click = true;
              drag_lock = false;
            };
          };

          gestures = {
            workspace_swipe_touch = true;
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
            disable_autoreload = true;

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
        sessionVariables = {
          ELECTRON_OZONE_PLATFORM_HINT = "wayland";
        };

      };

      programs = {
        # Image viewer
        swayimg.enable = true;
      };

      services = {
        hyprpaper = {
          enable = true;
          settings = {
            ipc = "on";
            splash = false;
            splash_offset = 2;
            preload = [ wallpaperPath ];
            wallpaper = map (conn: "${conn},${wallpaperPath}") (map monitorConnector cfg.monitors);
          };
        };

        playerctld.enable = true; # Media player control daemon

        # Clipboard history manager
        cliphist = {
          enable = true;
          systemdTargets = [ "hyprland-session.target" ];
        };
      };
    };

    # greetd at boot (was only in hyprlock.nix; noctalia uiShell left a TTY). Disable if using GDM etc:
    #   services.greetd.enable = lib.mkForce false;
    # Auto-login via `autoLogin` (hyprlock) or greeter modules' own greetd settings.
    security.pam.services.greetd.enableGnomeKeyring = true;
    services.greetd.enable = true;
    services.greetd.settings = lib.mkIf cfg.autoLogin (
      let
        autoLogin = {
          command = "${lib.getExe hyprlandPkg} > /dev/null 2>&1";
          inherit (env) user;
        };
      in
      {
        initial_session = autoLogin;
        default_session = autoLogin;
      }
    );
  };
}
