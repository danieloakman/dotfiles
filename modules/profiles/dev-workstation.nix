# Shared dev-workstation program enables for personal machines.
{ config, lib, env, ... }:
let
  cfg = config.my.profiles.devWorkstation;
in
{
  options.my.profiles.devWorkstation.enable = lib.mkEnableOption "Enable the dev workstation program profile.";

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        my.programs.agents.enable = lib.mkDefault true;
        my.programs.devPkgs.enable = lib.mkDefault true;
        my.programs.jsPackageSecurity.enable = lib.mkDefault true;
        my.programs.claude-code.enable = lib.mkDefault true;
        my.programs.cursor.enable = lib.mkDefault true;
        my.programs.gws.enable = lib.mkDefault true;
        my.programs.localsend.enable = lib.mkDefault true;
        my.programs.obsidian.enable = lib.mkDefault true;
        my.programs.herdr.enable = lib.mkDefault true;
        my.programs.micro.enable = lib.mkDefault true;
        my.programs.micro.isDefaultEditor = lib.mkDefault true;
      }
      (env.selectPlatform {
        linux = {
          my.programs.rtk.enable = lib.mkDefault true;
          my.programs.hunk.enable = lib.mkDefault true;
          my.scripts.bun.enable = lib.mkDefault true;
          my.programs.kitty.enable = lib.mkDefault true;
        };
      })
    ]
  );
}
