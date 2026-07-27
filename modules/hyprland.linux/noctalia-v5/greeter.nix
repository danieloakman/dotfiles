# Noctalia Greeter for greetd — always on with noctalia-v5.
# https://docs.noctalia.dev/v5/greeter/
# https://github.com/noctalia-dev/noctalia-greeter
{ config, lib, pkgs, env, inputs, ... }:
let
  inherit (lib) types;

  cfgEnabled = config.my.desktop.uiShell == "noctalia-v5";
  ncfg = config.my.desktop.noctaliaV5;
  hyprlandCfg = config.my.desktop.hyprland;

  # Hyprland monitor line → greeter layout entry:
  # "DP-2, 3440x1440, 1920x0, 1.0" → "DP-2:1920,0"
  layoutEntry =
    line:
    let
      parts = lib.splitString "," line;
      name = lib.trim (builtins.elemAt parts 0);
      # Hyprland uses "XxY"; greeter wants "X,Y".
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
    # Desktop Name= from hyprland.desktop (also listed by `noctalia-greeter sessions`).
    session.default = "Hyprland";
    keyboard.layout = "us";
    cursor = cursorSettings;
  }
  // lib.optionalAttrs (outputLayout != null) {
    output.layout = outputLayout;
  };

  finalSettings = lib.recursiveUpdate baseSettings ncfg.greeter.settingsExtra;
in
{
  imports = [ inputs.noctalia-greeter.nixosModules.default ];

  options.my.desktop.noctaliaV5.greeter.settingsExtra = lib.mkOption {
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

    # Opt out of hyprlock-style auto-login; this module owns the greetd session.
    my.desktop.hyprland.autoLogin = false;

    programs.noctalia-greeter = {
      enable = true;
      settings = finalSettings;
    };

    # Greeter looks here (and XDG_DATA_DIRS); greetd starts with an empty env so
    # the displayManager desktops path alone is not enough.
    environment.pathsToLink = [ "/share/wayland-sessions" ];

    # nixpkgs greetd defaults default_session.user to "greeter"; noctalia-greeter
    # sets default_session.command. Nothing else needed here.
  };
}
