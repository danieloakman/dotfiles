{ config, lib, pkgs, env, inputs, ... }:
let
  inherit (lib) types optionalAttrs;

  cfgEnabled = config.my.desktop.ui-shell == "noctalia";
  ncfg = config.my.desktop.noctalia;

  baseSettings = (builtins.fromJSON (builtins.readFile ./noctalia.json)).settings;

  # Optional overlays: null means “leave value from noctalia.json”.
  hostOverlaysList =
    lib.filter (x: x != { }) [
      (optionalAttrs (ncfg.bar.monitors != null) { bar.monitors = ncfg.bar.monitors; })
      (optionalAttrs (ncfg.general.avatar-image != null) {
        general.avatarImage = ncfg.general.avatar-image;
      })
      (optionalAttrs (ncfg.general.lock-screen-monitors != null) {
        general.lockScreenMonitors = ncfg.general.lock-screen-monitors;
      })
      (optionalAttrs (ncfg.location.name != null) { location.name = ncfg.location.name; })
      (optionalAttrs (ncfg.wallpaper.directory != null) {
        wallpaper.directory = ncfg.wallpaper.directory;
      })
      (optionalAttrs (ncfg.app-launcher.terminal-command != null) {
        appLauncher.terminalCommand = ncfg.app-launcher.terminal-command;
      })
      (optionalAttrs (ncfg.control-center.disk-path != null) {
        controlCenter.diskPath = ncfg.control-center.disk-path;
      })
      (optionalAttrs (ncfg.hooks.session != null) { hooks.session = ncfg.hooks.session; })
      { desktopWidgets.enabled = ncfg.desktop-widgets.enabled; }
      (optionalAttrs (ncfg.desktop-widgets.monitor-widgets != null) {
        desktopWidgets.monitorWidgets = ncfg.desktop-widgets.monitor-widgets;
      })
      { dock.enabled = ncfg.dock.enabled; }
      (optionalAttrs (ncfg.dock.monitors != null) { dock.monitors = ncfg.dock.monitors; })
      (optionalAttrs (ncfg.notifications.monitors != null) {
        notifications.monitors = ncfg.notifications.monitors;
      })
      (optionalAttrs (ncfg.osd.monitors != null) { osd.monitors = ncfg.osd.monitors; })
      (optionalAttrs (ncfg.color-schemes.monitor-for-colors != null) {
        colorSchemes.monitorForColors = ncfg.color-schemes.monitor-for-colors;
      })
    ];

  mergedAfterOverlays = lib.foldl' lib.recursiveUpdate baseSettings hostOverlaysList;

  applyTaskbarOnlySameOutput =
    settings:
    if ncfg.bar.taskbar-only-same-output == null then
      settings
    else
      let
        left = settings.bar.widgets.left or [ ];
        indexed = lib.imap0 (i: w: { inherit i w; }) left;
        hit = lib.findFirst (x: (x.w.id or "") == "Taskbar") null indexed;
      in
      if hit == null then
        settings
      else
        lib.recursiveUpdate settings {
          bar.widgets.left = lib.imap0
            (
              i: w: if i == hit.i then w // { onlySameOutput = ncfg.bar.taskbar-only-same-output; } else w
            )
            left;
        };

  mergedSettings = applyTaskbarOnlySameOutput mergedAfterOverlays;

  applyControlCenterBrightness =
    settings:
    if ncfg.control-center.enable-brightness-card == null then
      settings
    else
      lib.recursiveUpdate settings {
        controlCenter.cards =
          map
            (
              c:
              if (c.id or "") == "brightness-card" then
                c // { enabled = ncfg.control-center.enable-brightness-card; }
              else
                c
            )
            (settings.controlCenter.cards or [ ]);
      };

  pluginIdsToStrip = lib.concatLists [
    (lib.optional (!ncfg.bar.plugins.workspace-overview) [ "plugin:workspace-overview" ])
    (lib.optional (!ncfg.bar.plugins.tailscale) [ "plugin:tailscale" ])
    (lib.optional (!ncfg.bar.plugins.network-manager-vpn) [ "plugin:network-manager-vpn" ])
  ];

  stripBarPluginWidgets =
    settings:
    if pluginIdsToStrip == [ ] then
      settings
    else
      let
        strip = ws: lib.filter (w: !(builtins.elem (w.id or "") pluginIdsToStrip)) ws;
        bw = settings.bar.widgets or { };
      in
      lib.recursiveUpdate settings {
        bar.widgets = {
          left = strip (bw.left or [ ]);
          center = strip (bw.center or [ ]);
          right = strip (bw.right or [ ]);
        };
      };

  mergedWithExtras = lib.recursiveUpdate mergedSettings ncfg.settings-extra;

  finalSettings =
    stripBarPluginWidgets (applyControlCenterBrightness mergedWithExtras);

  noctaliaPkg = inputs.wrapper-modules.wrappers.noctalia-shell.wrap {
    inherit pkgs;
    # See https://birdeehub.github.io/nix-wrapper-modules/wrapperModules/noctalia-shell.html
    settings = finalSettings;
  };
  noctaliaCmd = lib.getExe noctaliaPkg;

  # IPC discovers the running shell via the user runtime dir; many terminals leave
  # XDG_RUNTIME_DIR unset, so `noctalia-shell ipc` cannot see the compositor instance.
  noctaliaSessionEnv = ''
    if [ -z "''${XDG_RUNTIME_DIR:-}" ] && [ -d "/run/user/$(id -u)" ]; then
      export XDG_RUNTIME_DIR="/run/user/$(id -u)"
    fi
  '';
in
{
  options.my.desktop.noctalia = {
    bar = {
      monitors = lib.mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = ''
          Hyprland / wlroots connector names for the bar
          (`settings.bar.monitors`), e.g. `["DP-1"]`. Per-machine.
        '';
      };
      taskbar-only-same-output = lib.mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = ''
          When set, overrides the Taskbar widget's `onlySameOutput` on the bar's left strip.
          Useful when multi-monitor layouts differ per host.
        '';
      };
      plugins = {
        workspace-overview = lib.mkOption {
          type = types.bool;
          default = true;
          description = "Include the `plugin:workspace-overview` widget on the bar.";
        };
        tailscale = lib.mkOption {
          type = types.bool;
          default = true;
          description = "Include the `plugin:tailscale` widget on the bar.";
        };
        network-manager-vpn = lib.mkOption {
          type = types.bool;
          default = true;
          description = "Include the `plugin:network-manager-vpn` widget on the bar.";
        };
      };
    };

    general = {
      avatar-image = lib.mkOption {
        type = types.nullOr types.str;
        default = "${env.home}/.face";
        description = "Path to lock screen / profile avatar (`settings.general.avatarImage`). Defaults to ~/.face";
      };
      lock-screen-monitors = lib.mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = ''
          Monitors where the lock screen is shown (`settings.general.lockScreenMonitors`).
          Empty list in stock config means default behavior.
        '';
      };
    };

    location = {
      name = lib.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          City / label for weather and calendar (`settings.location.name`).
        '';
      };
    };

    wallpaper = {
      directory = lib.mkOption {
        type = types.nullOr types.str;
        default = "${env.home}/repos/personal/dotfiles/files/assets";
        description = ''
          Wallpaper library directory (`settings.wallpaper.directory`). Host-local path.
        '';
      };
    };

    app-launcher = {
      terminal-command = lib.mkOption {
        type = types.nullOr types.str;
        default = if config.my.programs.kitty.enable then "kitty -e" else null;
        description = ''
          Command prefix to open a terminal (`settings.appLauncher.terminalCommand`), e.g. `"kitty -e"`.
          When Kitty is enabled (`my.programs.kitty.enable`), defaults to `"kitty -e"`; otherwise defaults
          to null so the value from `noctalia.json` is kept.
        '';
      };
    };

    control-center = {
      disk-path = lib.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Filesystem path for disk usage in the control center (`settings.controlCenter.diskPath`).";
      };
      enable-brightness-card = lib.mkOption {
        type = types.nullOr types.bool;
        default = env.deviceType == "laptop";
        description = ''
          When set, forces the brightness card on or off (`settings.controlCenter.cards` entry
          `brightness-card`). Use `false` on desktops without a backlight, `true` on laptops. Defaults to `true` on laptops.
        '';
      };
    };

    hooks = {
      session = lib.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Shell command run on session events (`settings.hooks.session`). Set to `null` to skip overriding and
          use whatever is already merged from the JSON base; use `""` to clear the hook.
        '';
      };
    };

    desktop-widgets = {
      enabled = lib.mkEnableOption "Enable desktop widgets";
      monitor-widgets = lib.mkOption {
        type =
          types.nullOr (
            types.listOf (
              types.submodule {
                options = {
                  name = lib.mkOption { type = types.str; };
                  widgets = lib.mkOption {
                    type = types.listOf types.anything;
                    default = [ ];
                    description = "Widget definitions for this output (`settings.desktop-widgets.monitor-widgets`).";
                  };
                };
              }
            )
          );
        default = null;
        description = ''
          Declares outputs for desktop widgets (`settings.desktop-widgets.monitor-widgets`).
          Names are connector IDs (e.g. `DP-2`) and vary by machine.
        '';
      };
    };

    dock = {
      enabled = lib.mkEnableOption "Enable the dock ";
      monitors = lib.mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Outputs where the dock appears (`settings.dock.monitors`).";
      };
    };

    notifications = {
      monitors = lib.mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Restrict notifications to these outputs (`settings.notifications.monitors`).";
      };
    };

    osd = {
      monitors = lib.mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Restrict OSD to these outputs (`settings.osd.monitors`).";
      };
    };

    color-schemes = {
      monitor-for-colors = lib.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Output used when deriving colors from wallpaper (`settings.color-schemes.monitor-for-colors`).
          Connector name; empty string means default in app.
        '';
      };
    };

    settings-extra = lib.mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = ''
        Extra attrset recursively merged into Noctalia `settings` after host-specific options.
        Escape hatch for keys not covered above.
      '';
    };
  };

  config = lib.mkIf cfgEnabled {
    assertions = [{
      # If we eventually added niri or some other type of wayland compositor, we would need to adjust this assertion:
      assertion = config.my.desktop.hyprland.enable;
      message = "Noctalia requires Hyprland to be enabled";
    }];

    # No dedicated greeter; passwordless greetd auto-login into Hyprland.
    my.desktop.hyprland.auto-login = true;

    environment.systemPackages = with pkgs; lib.mkMerge [
      [
        # Shim and wrapped pkg both install bin/noctalia-shell; hiPrio/lowPrio resolve the
        # clash so PATH uses the shim while the rest of noctaliaPkg (e.g. dump-noctalia-shell) stays installed.
        (lib.lowPrio noctaliaPkg)
        (lib.hiPrio (writeShellScriptBin "noctalia-shell" ''
          ${noctaliaSessionEnv}
          exec ${noctaliaCmd} "$@"
        ''))
        kdePackages.qtdeclarative # Required for qmlls, the QT lanaguage server

        pass
        wl-clipboard
        wtype # Required for pass-menu
        (writeShellScriptBin "noctalia-shell-save-settings" ''
          ${noctaliaSessionEnv}
          ${noctaliaCmd} ipc call state all > "$DOTFILES_DIR/modules/hyprland.linux/noctalia/noctalia.json"
        '')
        (writeShellScriptBin "noctalia-shell-ipc-show" ''
          ${noctaliaSessionEnv}
          ${noctaliaCmd} ipc show
        '')
      ]
      (lib.mkIf (env.deviceType == "laptop") [
        upower # Required for battery status
      ])
    ];

    home-manager.users.${env.user} = { config, lib, ... }:
      let
        hl = import ../_lua-lib.nix { inherit lib; };
        noctaliaIpc = "${noctaliaCmd} ipc call";
      in
      {
      # Store the plugin in the nix store (can't debug):
      xdg.configFile."noctalia/plugins/pass-menu".source = ./plugins/pass-menu;

      # Point at the git checkout (not a store copy) so plugin sources can be edited live.
      # xdg.configFile."noctalia/plugins/pass-menu".source =
      #   config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/repos/personal/dotfiles/modules/hyprland.linux/noctalia/plugins/pass-menu";

      wayland.windowManager.hyprland = {
        settings = {
          on = [
            (hl.onStart [ noctaliaCmd ])
          ];

          bind = [
            (hl.bind (hl.key "space") (hl.exec "${noctaliaIpc} launcher toggle"))
            (hl.bind (hl.key "Q") (hl.exec "${noctaliaIpc} plugin:pass-menu toggle"))
            (hl.bind (hl.key "S") (hl.exec "${noctaliaIpc} plugin:web-search toggle"))
            (hl.bind (hl.key "G") (hl.exec "${noctaliaIpc} launcher emoji"))

            (hl.bindl "XF86MonBrightnessUp" (hl.exec "${noctaliaIpc} brightness increase"))
            (hl.bindl "XF86MonBrightnessDown" (hl.exec "${noctaliaIpc} brightness decrease"))
            (hl.bindl "XF86AudioRaiseVolume" (hl.exec "${noctaliaIpc} volume increase"))
            (hl.bindl "XF86AudioLowerVolume" (hl.exec "${noctaliaIpc} volume decrease"))
            (hl.bindl "ALT + F7" (hl.exec "${noctaliaIpc} volume increase"))
            (hl.bindl "ALT + F6" (hl.exec "${noctaliaIpc} volume decrease"))
            (hl.bindl "XF86AudioMicMute" (hl.exec "${noctaliaIpc} volume muteInput"))
            (hl.bindl "XF86AudioMute" (hl.exec "${noctaliaIpc} volume muteOutput"))
            (hl.bindl "XF86AudioPlay" (hl.exec "${noctaliaIpc} media playPause"))
            (hl.bindl "XF86AudioPrev" (hl.exec "${noctaliaIpc} media previous"))
            (hl.bindl "XF86AudioNext" (hl.exec "${noctaliaIpc} media next"))
          ];
        };
      };
    };
  };
}
