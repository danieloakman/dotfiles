{ config, lib, env, ... }:
let
  cfg = config.my.programs.obsidian;
in
{
  options.my.programs.obsidian.enable = lib.mkEnableOption "Enable Obsidian via the Home Manager module.";

  config = lib.mkIf cfg.enable {
    home-manager.users.${env.user}.programs.obsidian = {
      enable = true;
      cli.enable = true;
    };
  };
}
