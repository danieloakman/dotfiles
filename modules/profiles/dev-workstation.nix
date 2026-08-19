# Shared dev-workstation program enables for personal machines.
{ config, lib, env, ... }:
let
  cfg = config.my.profiles.dev-workstation;
in
{
  options.my.profiles.dev-workstation.enable = lib.mkEnableOption "Enable the dev workstation program profile.";

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        my.programs = {
          agents.enable = lib.mkDefault true;
          dev-pkgs.enable = lib.mkDefault true;
          js-package-security.enable = lib.mkDefault true;
          claude-code.enable = lib.mkDefault true;
          cursor.enable = lib.mkDefault true;
          gws.enable = lib.mkDefault true;
          localsend.enable = lib.mkDefault true;
          obsidian.enable = lib.mkDefault true;
          herdr.enable = lib.mkDefault true;
          micro = {
            enable = lib.mkDefault true;
            is-default-editor = lib.mkDefault true;
          };
        };
      }
      (env.selectPlatform {
        linux = {
          my = {
            programs = {
              rtk.enable = lib.mkDefault true;
              hunk.enable = lib.mkDefault true;
              kitty.enable = lib.mkDefault true;
            };
            programs.bun-scripts.enable = lib.mkDefault true;
          };
        };
      })
    ]
  );
}
