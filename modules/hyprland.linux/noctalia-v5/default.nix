{ config, lib, pkgs, env, inputs, ... }:
let
  inherit (lib) types;

  cfgEnabled = config.my.desktop.ui-shell == "noctalia-v5";
  ncfg = config.my.desktop.noctalia-v5;

  # First token of a Hyprland monitor line ("DP-2, 3440x1440@144Hz, …").
  connectorOf = line: builtins.head (lib.splitString "," line);
  allConnectors = map connectorOf config.my.desktop.hyprland.monitors;

  # Emulate v4 `bar.monitors` allow-list: disable bar on connectors not listed.
  # https://docs.noctalia.dev/v5/bar/
  disabledBarConnectors =
    if ncfg.bar.monitors == null then
      [ ]
    else
      lib.filter (c: !(builtins.elem c ncfg.bar.monitors)) allConnectors;

  barMonitorOverrides = lib.genAttrs disabledBarConnectors (_: { enabled = false; });

  # Host-specific declarative config; GUI state (~/.local/state/noctalia/settings.toml) overrides.
  baseSettings = lib.recursiveUpdate
    {
      # https://docs.noctalia.dev/v5/bar/
      bar = {
        order = [ "main" ];
        main = {
          position = ncfg.bar.position;
          start = [ "launcher" "wallpaper" "workspaces" "active_window" ];
          center = [ "clock" "spacer_2" "media" ];
          end = [
            "group:g1"
            "tray"
            "notifications"
            "clipboard"
            "network"
            "bluetooth"
            "volume"
            "brightness"
            "battery"
            "control-center"
            "session"
          ];
          capsule_group = [
            {
              id = "g1";
              enabled = true;
              fill = "surface_variant";
              members = [ "network_rx" "cpu" ];
              opacity = 1.0;
              padding = 6.0;
            }
          ];
        }
        // lib.optionalAttrs (barMonitorOverrides != { }) { monitor = barMonitorOverrides; };
      };
      widget = {
        clock = {
          format = "{:%-I:%M %p %a, %b %d}";
          vertical_format = "{:%H %M - %d %m}";
          tooltip_format = "{:%H:%M %a, %b %d}";
        };
        spacer_2.type = "spacer";
      };
      shell.launcher.providers.session.global = true;
      # https://docs.noctalia.dev/v5/services/notifications/
      notification.position = "top_center";
      # https://docs.noctalia.dev/v5/services/idle/
      idle = {
        pre_action_fade_seconds = 2.0;
        behavior_order = [ "screen-off" "lock-and-suspend" ];
        behavior = {
          "screen-off" = {
            action = "screen_off";
            enabled = true;
            timeout = 600;
          };
          "lock-and-suspend" = {
            action = "lock_and_suspend";
            enabled = true;
            timeout = 900;
          };
        };
      };
      plugins = {
        enabled = [ "local/pass" "local/web-search" ];
        # Declaring source replaces built-ins; re-list official + community + our checkout.
        source = [
          {
            name = "official";
            kind = "git";
            location = "https://github.com/noctalia-dev/official-plugins";
            enabled = true;
          }
          {
            name = "community";
            kind = "git";
            location = "https://github.com/noctalia-dev/community-plugins";
            enabled = true;
          }
          {
            name = "dotfiles";
            kind = "path";
            location = "${env.home}/repos/personal/dotfiles/modules/hyprland.linux/noctalia-v5/plugins";
            enabled = true;
          }
        ];
      };
    }
    (
      lib.optionalAttrs (ncfg.avatar-image != null) { shell.avatar_path = ncfg.avatar-image; }
      // lib.optionalAttrs (ncfg.wallpaper.directory != null) { wallpaper.directory = ncfg.wallpaper.directory; }
      // lib.optionalAttrs (ncfg.location.address != null) { location.address = ncfg.location.address; }
    );

  finalSettings = lib.recursiveUpdate baseSettings ncfg.settings-extra;

  # Snapshot GUI state (v5 does not rewrite ~/.config/noctalia).
  dumpSettings = pkgs.writeShellScriptBin "noctalia-dump-settings" ''
    state="''${XDG_STATE_HOME:-$HOME/.local/state}/noctalia/settings.toml"
    if [ -f "$state" ]; then
      cat "$state"
    else
      echo "No noctalia GUI state at $state" >&2
      exit 1
    fi
  '';
in
{
  options.my.desktop.noctalia-v5 = {
    avatar-image = lib.mkOption {
      type = types.nullOr types.str;
      default = "${env.home}/.face";
      description = "Path to the profile/lock-screen avatar (`[shell] avatar_path`). Defaults to ~/.face; null keeps the v5 default.";
    };

    bar = {
      position = lib.mkOption {
        type = types.enum [ "top" "bottom" "left" "right" ];
        default = "top";
        description = "Bar edge (`[bar.main] position`).";
      };
      monitors = lib.mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = ''
          Connector names the bar should appear on, e.g. `[ "DP-2" ]`. v5 spawns
          a bar on every monitor; when this is set, the bar is disabled on every
          `my.desktop.hyprland.monitors` connector not listed here. Null shows it
          everywhere.
        '';
      };
    };

    wallpaper.directory = lib.mkOption {
      type = types.nullOr types.str;
      default = "${env.home}/repos/personal/dotfiles/files/assets";
      description = "Wallpaper library directory (`[wallpaper] directory`). Host-local path.";
    };

    location.address = lib.mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "City / label geocoded for weather and night-light (`[location] address`), e.g. `\"Sydney\"`.";
    };

    settings-extra = lib.mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = ''
        Extra attrset recursively merged into `programs.noctalia.settings` (v5 TOML)
        after the host-specific options above. Escape hatch for keys not covered here.
      '';
    };
  };

  config = lib.mkIf cfgEnabled {
    assertions = [{
      # Extend this if a non-Hyprland Wayland compositor is ever supported.
      assertion = config.my.desktop.hyprland.enable;
      message = "Noctalia requires Hyprland to be enabled";
    }];

    home-manager.users.${env.user} = { ... }: {
      imports = [ inputs.noctalia.homeModules.default ];

      programs.noctalia = {
        enable = true;
        # Launched via Hyprland exec-once below; set true to use the systemd user service instead.
        systemd.enable = false;
        settings = finalSettings;
      };

      home.packages = [
        pkgs.wl-clipboard
        pkgs.wtype # Required for local/pass auto-paste after copy
        dumpSettings
      ];

      wayland.windowManager.hyprland = {
        settings = {
          exec-once = [ "noctalia" ];

          "$noctaliaMsg" = "noctalia msg";

          bind = [
            "$mod, space, exec, $noctaliaMsg panel-toggle launcher" # Application launcher
            "$mod, Q, exec, $noctaliaMsg panel-toggle launcher '/pass '" # Password-store (local/pass)
            "$mod, S, exec, $noctaliaMsg panel-toggle launcher '/web '" # Web search (local/web-search)
            "$mod, G, exec, $noctaliaMsg panel-toggle launcher /emo" # Emoji picker (launcher emoji provider)
          ];
          bindl = [
            ", XF86MonBrightnessUp, exec, $noctaliaMsg brightness-up"
            ", XF86MonBrightnessDown, exec, $noctaliaMsg brightness-down"
            ", XF86AudioRaiseVolume, exec, $noctaliaMsg volume-up"
            ", XF86AudioLowerVolume, exec, $noctaliaMsg volume-down"
            "alt, F7, exec, $noctaliaMsg volume-up" # XF86 volume keys don't work on some keyboards
            "alt, F6, exec, $noctaliaMsg volume-down"
            ", XF86AudioMicMute, exec, $noctaliaMsg mic-mute"
            ", XF86AudioMute, exec, $noctaliaMsg volume-mute"
            ", XF86AudioPlay, exec, $noctaliaMsg media toggle"
            ", XF86AudioPrev, exec, $noctaliaMsg media previous"
            ", XF86AudioNext, exec, $noctaliaMsg media next"
          ];
        };
      };
    };
  };
}
