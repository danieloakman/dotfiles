# https://docs.noctalia.dev/v5/greeter/
# https://github.com/noctalia-dev/noctalia-greeter
{ config, lib, pkgs, env, inputs, ... }:
let
  inherit (lib) types;

  cfgEnabled = config.my.desktop.ui-shell == "noctalia-v5";
  ncfg = config.my.desktop.noctalia-v5;
  hyprlandCfg = config.my.desktop.hyprland;

  # "DP-2, 3440x1440, 1920x0, 1.0" → "DP-2:1920,0" (Hyprland XxY → greeter X,Y)
  layoutEntry =
    line:
    let
      parts = lib.splitString "," line;
      name = lib.trim (builtins.elemAt parts 0);
      pos = builtins.replaceStrings [ "x" ] [ "," ] (lib.trim (builtins.elemAt parts 2));
    in
    "${name}:${pos}";

  outputLayout =
    if hyprlandCfg.monitors == [ ] then
      null
    else
      lib.concatMapStringsSep "; " layoutEntry hyprlandCfg.monitors;

  stylixCursor = config.stylix.cursor or null;
  cursorSettings =
    if stylixCursor != null && (stylixCursor.name or null) != null then
      {
        theme = stylixCursor.name;
        size = stylixCursor.size or 24;
        path = "${stylixCursor.package}/share/icons";
      }
    else
      {
        theme = "Bibata-Modern-Ice";
        size = 24;
        path = "${pkgs.bibata-cursors}/share/icons";
      };

  baseSettings = {
    user.default = env.user;
    session.default = "Hyprland"; # Name= from hyprland.desktop
    keyboard.layout = "us";
    cursor = cursorSettings;
  }
  // lib.optionalAttrs (outputLayout != null) {
    output.layout = outputLayout;
  };

  finalSettings = lib.recursiveUpdate baseSettings ncfg.greeter.settings-extra;
in
{
  imports = [ inputs.noctalia-greeter.nixosModules.default ];

  options.my.desktop.noctalia-v5.greeter.settings-extra = lib.mkOption {
    type = types.attrsOf types.anything;
    default = { };
    description = ''
      Extra attrset recursively merged into `programs.noctalia-greeter.settings`
      (written to `/var/lib/noctalia-greeter/greeter.toml`).
    '';
  };

  config = lib.mkIf cfgEnabled {
    assertions = [
      {
        assertion = hyprlandCfg.enable;
        message = "Noctalia greeter requires Hyprland to be enabled";
      }
    ];

    # This module owns greetd; disable hyprlock-style auto-login.
    my.desktop.hyprland.auto-login = false;

    programs.noctalia-greeter = {
      enable = true;
      settings = finalSettings;
    };

    # greetd starts with an empty env; link sessions so the greeter can find them.
    environment.pathsToLink = [ "/share/wayland-sessions" ];
  };
}
