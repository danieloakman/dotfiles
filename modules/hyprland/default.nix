# Hyprland module for system level configuration.
# See: https://www.youtube.com/watch?v=zt3hgSBs11g

{ pkgs, inputs, env, config, ... }:
let
  startupScript = pkgs.pkgs.writeShellScriptBin "start" ''
    ${pkgs.pyprland}/bin/pypr &

    sleep 1
  '';
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
    ./touch-screen.nix

    # UI Shells:
    # ./waybar.nix
    ./ags
    # ./quickshell
  ];

  environment = {
    sessionVariables = {
      NIXOS_OZONE_WL = "1";
    };
    systemPackages = with pkgs; [
      pyprland # Extra Hyprland utils/tools
      hyprpicker # Color picker
      # hyprcursor # Cursor. Stylix seems to handle cursors on wayland, so don't need this.
      rofi-wayland # Make sure it's installed, even though we have imported rofi.nix
      brightnessctl # Control backlight brightness
      libnotify # Adds notification commands like `notify-send`
      wev # Wayland event viewer. Useful for finding uncommon key codes
      uwsm # Universal Wayland session manager. Can do `uwsm `
      hyprshot # Screenshot tool # TODO: move to programs.hyprshot.enable
      rofi-network-manager # Rofi network manager GUI
      nautilus # File explorer
      gnome-disk-utility # Gnome disk utility for formatting drives
    ];
  };

  programs = {
    hyprland = {
      enable = true;
      package = hyprPkgs.hyprland;
    };
    seahorse.enable = true; # optional GUI tool for Gnome keyring
  };

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
        "$files" = "nautilus";
        "$browser" = "uwsm app -- vivaldi --ozone-platform=wayland";
        "$webapp" = "$browser --app";

        # `l` flag denotes these will also work when an input inhibitor is active
        bindl = [
          ", XF86MonBrightnessUp, exec, swayosd-client --brightness 5"
          ", XF86MonBrightnessDown, exec, swayosd-client --brightness -5"
          ", XF86AudioRaiseVolume, exec, swayosd-client --output-volume 5"
          ", XF86AudioLowerVolume, exec, swayosd-client --output-volume -5"
          "alt, F7, exec, swayosd-client --output-volume 5" # Need these because XF86 volume keys don't work sometimes
          "alt, F6, exec, swayosd-client --output-volume -5"
          ", XF86AudioMicMute, exec, swayosd-client --input-volume mute-toggle"
          ", XF86AudioMute, exec, swayosd-client --output-volume mute-toggle"
          ", XF86AudioPlay, exec, swayosd-client --playerctl play-pause"
          ", XF86AudioPrev, exec, swayosd-client --playerctl prev"
          ", XF86AudioNext, exec, swayosd-client --playerctl next"
        ];

        bindr = [
          "CAPS, Caps_Lock, exec, swayosd-client --caps-lock"
          # "NUM, Num_Lock, exec, swayosd-client --num-lock" # TODO: fix this
        ];

        bindm = [
          # mouse movements
          "$mod, mouse:272, movewindow"
          "$mod, mouse:273, resizewindow"
        ];

        bind = [
          "$mod, space, exec, rofi -show combi -combi-modi \"window,drun\" -modi combi -show-icons"
          "$mod, S, exec, rofi-google-search"
          "$mod, K, exec, kill-processes"
          "alt, F4, killactive"
          "$mod, C, killactive"
          "$mod, V, togglefloating"
          "$mod, F10, exec, ${gamemodeScript}/bin/start"
          "$mod, T, exec, $files"
          ", Print, exec, hyprshot -o ~/Pictures/Screenshots -m region"
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

      file = {
        ".config/hypr/pyprland.toml".text = ''
          [pyprland]
          terminal = "kitty"
        '';
      };
    };

    programs = {
      # Image viewer
      swayimg.enable = true;
      # Screenshot tool.
      # hyprshot.enable = true; # TODO: add this back in once it's available for our pinned version of home-manager
    };

    services = {
      hyprpaper = {
        enable = true;
        settings =
          let
            wallpaperPath = "${env.home}/repos/personal/dotfiles/files/assets/${config.networking.hostName}-wallpaper.jpeg";
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

      playerctld.enable = true; # Media player control daemon

      # Clipboard history manager
      cliphist = {
        enable = true;
        systemdTargets = [ "hyprland-session.target" ];
      };

      # Don't need these anymore if we're using AGS and its custom notification backend.
      swaync = {
        enable = true; # Notification daemon
        settings = {
          # positionX = "center";
          # positionY = "top";
          # layer = "overlay";
          # control-center-layer = "top";
          # layer-shell = true;
          # cssPriority = "application";
          # control-center-margin-top = 0;
          # control-center-margin-bottom = 0;
          # control-center-margin-right = 0;
          # control-center-margin-left = 0;
          # notification-2fa-action = true;
          # notification-inline-replies = false;
          # notification-icon-size = 64;
          # notification-body-image-height = 100;
          # notification-body-image-width = 200;
        };
      };
      swayosd = {
        # This is supposed to popup with volume changes and other notifications like that but isn't?
        enable = true;
      };
    };

    xdg.desktopEntries =
      let
        webapp = url: "uwsm app -- vivaldi --ozone-platform=wayland --app=\"${url}\"";
      in
      {
        # Webapps:
        youtube = {
          name = "YouTube";
          exec = webapp "https://www.youtube.com";
          categories = [ "Network" "WebBrowser" ];
          icon = "youtube";
          startupNotify = true;
        };
        instagram-chats = {
          name = "Instagram Chats";
          exec = webapp "https://www.instagram.com/direct/inbox/";
          categories = [ "Network" "Chat" ];
          icon = "instagram";
          startupNotify = true;
        };
        claude = {
          name = "Claude AI";
          exec = webapp "https://claude.ai/chat";
          categories = [ "Network" "WebBrowser" ];
          icon = "claude";
          startupNotify = true;
        };
        gemini = {
          name = "Gemini";
          exec = webapp "https://gemini.google.com";
          categories = [ "Network" "WebBrowser" ];
          icon = "gemini";
          startupNotify = true;
        };
        google-drive = {
          name = "Google Drive";
          exec = webapp "https://drive.google.com";
          categories = [ "Network" "FileTransfer" ];
          icon = "google-drive";
          startupNotify = true;
        };
        gmail = {
          name = "Gmail";
          exec = webapp "https://mail.google.com";
          categories = [ "Network" "Email" ];
          icon = "gmail";
          startupNotify = true;
        };
        google-calendar = {
          name = "Google Calendar";
          exec = webapp "https://calendar.google.com";
          categories = [ "Network" "Calendar" ];
          icon = "google-calendar";
          startupNotify = true;
        };
        nixos-search-packages = {
          name = "NixOS Search Packages";
          exec = webapp "https://search.nixos.org/packages?channel=unstable";
          categories = [ "System" "Development" ];
          icon = "nixos";
          startupNotify = true;
        };
        home-manager-config = {
          name = "NixOS Home Manager Configuration Search";
          exec = webapp "https://home-manager-options.extranix.com/?query=&release=master";
          categories = [ "System" "Development" ];
          icon = "home-manager";
          startupNotify = true;
        };
        google-taskboard = {
          name = "Google Taskboard";
          exec = webapp "https://tasksboard.com/app";
          categories = [ "Network" ];
          icon = "google-tasks";
          startupNotify = true;
        };
        google-photos = {
          name = "Google Photos";
          exec = webapp "https://photos.google.com";
          categories = [ "Network" ];
          icon = "google-photos";
          startupNotify = true;
        };
        google-mobile-messages = {
          name = "Google Mobile Messages";
          exec = webapp "https://messages.google.com/web/conversations";
          categories = [ "Network" "Chat" ];
          icon = "google-messages";
          startupNotify = true;
        };
        disney-plus = {
          name = "Disney Plus";
          exec = webapp "https://www.disneyplus.com";
          categories = [ "Network" ];
          icon = "disney-plus";
          startupNotify = true;
        };
        netflix = {
          name = "Netflix";
          exec = webapp "https://www.netflix.com";
          categories = [ "Network" ];
          icon = "netflix";
          startupNotify = true;
        };
        stan = {
          name = "Stan";
          exec = webapp "https://www.stan.com.au";
          categories = [ "Network" ];
          icon = "stan";
          startupNotify = true;
        };
        amazon-prime = {
          name = "Amazon Prime";
          exec = webapp "https://www.primevideo.com/";
          categories = [ "Network" ];
          icon = "amazon-prime";
          startupNotify = true;
        };
        audible = {
          name = "Audible";
          exec = webapp "https://www.audible.com.au/library";
          categories = [ "Network" ];
          icon = "audible";
          startupNotify = true;
        };

        # System management:
        shutdown = {
          name = "Shutdown";
          exec = "shutdown -P now";
          categories = [ "System" ];
          icon = "shutdown";
          startupNotify = true;
        };
        reboot = {
          name = "Reboot";
          exec = "reboot";
          categories = [ "System" ];
          icon = "reboot";
          startupNotify = true;
        };
        suspend = {
          name = "Suspend";
          exec = "systemctl suspend";
          categories = [ "System" ];
          icon = "suspend";
          startupNotify = true;
        };
        logout = {
          name = "Logout";
          exec = "logout";
          categories = [ "System" ];
          icon = "logout";
          startupNotify = true;
        };
      };
  };
}
