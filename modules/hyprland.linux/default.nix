# Hyprland module for system level configuration.
# See: https://www.youtube.com/watch?v=zt3hgSBs11g

{ pkgs, env, lib, config, ... }:
let
  cfg = config.my.desktop.hyprland;
  hyprlandPkg = pkgs.hyprland;
  wallpaperPath = lib.optionalString (cfg.hyprpaper.wallpaper != null) (toString cfg.hyprpaper.wallpaper);
  gamemodeScript = pkgs.writeShellScriptBin "start" ''
    HYPRGAMEMODE=$(hyprctl getoption animations:enabled | awk 'NR==1{print $2}')
    if [ "$HYPRGAMEMODE" = 1 ] ; then
      hyprctl --batch "\
        keyword animations:enabled 0;\
        keyword decoration:shadow:enabled 0;\
        keyword decoration:blur:enabled 0;\
        keyword general:gaps_in 0;\
        keyword general:gaps_out 0;\
        keyword general:border_size 1;\
        keyword decoration:rounding 0"
      exit
    fi
    hyprctl reload
  '';
  screenSaveScript = pkgs.writeShellScriptBin "screen-save" ''
    mouse_move_enables_dpms=$(hyprctl getoption misc:mouse_move_enables_dpms | awk 'NR==1{print $2}')
    if [ "$mouse_move_enables_dpms" = 1 ] ; then
      hyprctl keyword misc:mouse_move_enables_dpms 0
      hyprctl dispatch dpms off
    else
      hyprctl keyword misc:mouse_move_enables_dpms 1
      hyprctl dispatch dpms on
    fi
  '';
  vivaldiExe = lib.getExe pkgs.vivaldi;
  monitorOptionType = lib.types.submodule {
    options = {
      output = lib.mkOption {
        type = lib.types.str;
        description = "Monitor output name, e.g. DP-1.";
      };
      mode = lib.mkOption {
        type = lib.types.str;
        default = "preferred";
        description = "Resolution and refresh rate, e.g. 1920x1080@144.";
      };
      position = lib.mkOption {
        type = lib.types.str;
        default = "auto";
        description = "Layout position, e.g. 0x0.";
      };
      scale = lib.mkOption {
        type = lib.types.either lib.types.float lib.types.str;
        default = 1.0;
        description = "Scale factor, e.g. 1.0 or \"auto\".";
      };
    };
  };
  workspaceOptionType = lib.types.submodule {
    options = {
      workspace = lib.mkOption {
        type = lib.types.str;
        description = "Workspace id or name, e.g. \"1\".";
      };
      monitor = lib.mkOption {
        type = lib.types.str;
        description = "Monitor to bind this workspace to.";
      };
    };
  };
  windowRuleOptionType = lib.types.attrsOf lib.types.anything;
in
{
  options.my.desktop = {
    # Under desktop (not hyprland) so shells can be reused with other compositors (e.g. Niri).
    ui-shell = lib.mkOption {
      type = lib.types.enum [ "ags" "noctalia" "noctalia-v5" "waybar" null ];
      default = null;
      description = "The UI shell to use for the desktop environment.";
    };
  };

  options.my.desktop.hyprland = {
    enable = lib.mkEnableOption "Enable the Hyprland desktop environment.";

    monitors = lib.mkOption {
      type = lib.types.listOf monitorOptionType;
      default = [ ];
      description = ''
        Per-machine Hyprland monitors (`hl.monitor`), e.g.
        `{ output = "DP-1"; mode = "1920x1080"; position = "0x0"; scale = 1.0; }`.
      '';
    };

    workspaces = lib.mkOption {
      type = lib.types.listOf workspaceOptionType;
      default = [ ];
      description = ''
        Optional workspace-to-monitor bindings (`hl.workspace_rule`), e.g.
        `{ workspace = "1"; monitor = "DP-1"; }`.
      '';
    };

    window-rules = lib.mkOption {
      type = lib.types.listOf windowRuleOptionType;
      default = [ ];
      description = ''
        Optional Hyprland window rules (`hl.window_rule`), e.g.
        `{ match.class = "^(firefox)$"; workspace = "1"; }`.
      '';
    };

    hyprpaper = {
      wallpaper = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Wallpaper image for hyprpaper on all configured monitors.";
      };
    };

    auto-login = lib.mkOption {
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
        kitty.enable = lib.mkDefault true;
        ydotool.enable = lib.mkDefault true;
        rofi.enable = lib.mkDefault true;
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
      desktop.hyprland = {
        hyprshot.enable = lib.mkDefault true;
        # Haven't found a need for this again:
        pyprland.enable = false;
      };
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

    home-manager.users.${env.user} = { lib, ... }:
      let
        hl = import ./_lua-lib.nix { inherit lib; };
        browserCmd = "uwsm app -- ${vivaldiExe} --ozone-platform=wayland";
      in
      {
        wayland.windowManager.hyprland = {
          enable = true;
          package = hyprlandPkg;
          configType = "lua";

          settings = {
            mod = hl.var "SUPER";
            files = hl.var "nautilus";
            browser = hl.var browserCmd;

            monitor = map (m: {
              inherit (m) output mode position scale;
            }) cfg.monitors;

            workspace_rule = map (w: {
              inherit (w) workspace monitor;
            }) cfg.workspaces;

            window_rule = cfg.window-rules;

            bind = [
              (hl.bindm (hl.key "mouse:272") hl.drag)
              (hl.bindm (hl.key "mouse:273") hl.resize)

              (hl.bind (hl.key "K") (hl.exec "rofi-kill-processes"))
              (hl.bind "ALT + F4" hl.close)
              (hl.bind (hl.key "C") hl.close)
              (hl.bind (hl.key "V") hl.floatToggle)
              (hl.bind (hl.key "F10") (hl.exec (lib.getExe gamemodeScript)))
              (hl.bind (hl.key "F9") (hl.exec (lib.getExe screenSaveScript)))
              (hl.bind (hl.key "T") (lib.generators.mkLuaInline "hl.dsp.exec_cmd(files)"))
              (hl.bind (hl.key "P") (hl.exec "hyprpicker -a"))
              (hl.bind (hl.key "B") (lib.generators.mkLuaInline "hl.dsp.exec_cmd(browser)"))

              (hl.bind (hl.key "left") (hl.focusDir "l"))
              (hl.bind (hl.key "h") (hl.focusDir "l"))
              (hl.bind (hl.key "right") (hl.focusDir "r"))
              (hl.bind (hl.key "l") (hl.focusDir "r"))
              (hl.bind (hl.key "up") (hl.focusDir "u"))
              (hl.bind (hl.key "k") (hl.focusDir "u"))
              (hl.bind (hl.key "down") (hl.focusDir "d"))
              (hl.bind (hl.key "j") (hl.focusDir "d"))

              (hl.bind (hl.keyShift "right") (hl.moveToWs "+1"))
              (hl.bind (hl.keyShift "left") (hl.moveToWs "-1"))
            ]
            ++ (
              builtins.concatLists (builtins.genList
                (
                  x:
                  let
                    ws =
                      let
                        c = (x + 1) / 10;
                      in
                      builtins.toString (x + 1 - (c * 10));
                    n = x + 1;
                  in
                  [
                    (hl.bind (hl.key ws) (hl.focusWs n))
                    (hl.bind (hl.keyShift ws) (hl.moveToWs n))
                  ]
                )
                10)
            );

            config = {
              dwindle = {
                preserve_split = true;
                special_scale_factor = 0.95;
              };

              master = {
                new_status = "master";
                new_on_top = true;
                mfact = 0.5;
              };

              general = {
                border_size = 2;
                gaps_in = 6;
                gaps_out = 8;
                resize_on_border = true;
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
              };

              binds = {
                workspace_back_and_forth = true;
                allow_workspace_cycles = true;
                pass_mouse_when_bound = false;
              };

              input = {
                kb_layout = "us";
                repeat_rate = 50;
                repeat_delay = 300;
                numlock_by_default = true;
                left_handed = false;
                follow_mouse = 1;
                float_switch_override_focus = 0;
                touchpad = {
                  disable_while_typing = true;
                  natural_scroll = true;
                  clickfinger_behavior = false;
                  middle_button_emulation = true;
                  tap_to_click = true;
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
              };

              xwayland = {
                force_zero_scaling = true;
              };

              misc = {
                disable_hyprland_logo = true;
                disable_splash_rendering = true;
                middle_click_paste = false;
                disable_autoreload = true;
                mouse_move_enables_dpms = true;
                enable_swallow = true;
                swallow_regex = "^(kitty)$";
                focus_on_activate = false;
                initial_workspace_tracking = 0;
              };
            };

            curve = [
              (hl.args [
                "wind"
                { type = "bezier"; points = [ [ 0.05 0.9 ] [ 0.1 1.05 ] ]; }
              ])
              (hl.args [
                "winIn"
                { type = "bezier"; points = [ [ 0.1 1.1 ] [ 0.1 1.1 ] ]; }
              ])
              (hl.args [
                "winOut"
                { type = "bezier"; points = [ [ 0.3 (-0.3) ] [ 0 1 ] ]; }
              ])
              (hl.args [
                "liner"
                { type = "bezier"; points = [ [ 1 1 ] [ 1 1 ] ]; }
              ])
            ];

            animation = [
              { leaf = "windows"; enabled = true; speed = 6; bezier = "wind"; style = "slide"; }
              { leaf = "windowsIn"; enabled = true; speed = 6; bezier = "winIn"; style = "slide"; }
              { leaf = "windowsOut"; enabled = true; speed = 5; bezier = "winOut"; style = "slide"; }
              { leaf = "windowsMove"; enabled = true; speed = 5; bezier = "wind"; style = "slide"; }
              { leaf = "border"; enabled = true; speed = 1; bezier = "liner"; }
              { leaf = "borderangle"; enabled = true; speed = 100; bezier = "liner"; style = "loop"; }
              { leaf = "fade"; enabled = true; speed = 10; bezier = "default"; }
              { leaf = "workspaces"; enabled = true; speed = 5; bezier = "wind"; }
            ];

            gesture = [
              {
                fingers = 3;
                direction = "horizontal";
                action = "workspace";
              }
            ];
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
              wallpaper = map (m: "${m.output},${wallpaperPath}") cfg.monitors;
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

    # greetd at boot (was only in hyprlock.nix; noctalia ui-shell left a TTY). Disable if using GDM etc:
    #   services.greetd.enable = lib.mkForce false;
    # Auto-login via `auto-login` (hyprlock) or greeter modules' own greetd settings.
    security.pam.services.greetd.enableGnomeKeyring = true;
    services.greetd.enable = true;
    services.greetd.settings = lib.mkIf cfg.auto-login (
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
