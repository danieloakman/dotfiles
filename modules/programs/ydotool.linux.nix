{ env, pkgs, lib, config, ... }:
let
  cfg = config.my.programs.ydotool;
  group = "ydotool";
in
{
  options.my.programs.ydotool.enable = lib.mkEnableOption "Enable the ydotool package and daemon";

  config = lib.mkIf cfg.enable ({
    assertions = [
      {
        assertion = config.my.desktop.hyprland.enable;
        message = "ydotool requires Hyprland to be enabled";
      }
    ];
    environment.systemPackages = with pkgs; [
      ydotool
    ];
    programs.ydotool = {
      enable = true;
      inherit group;
    };
    users.users.${env.user}.extraGroups = [ group ];
  });
}
