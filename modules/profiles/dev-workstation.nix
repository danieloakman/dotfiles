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
          agents.enable = true;
          dev-pkgs.enable = true;
          js-package-security.enable = true;
          claude-code.enable = true;
          cursor.enable = true;
          gws.enable = true;
          localsend.enable = true;
          obsidian.enable = true;
          herdr.enable = true;
          micro = {
            enable = true;
            is-default-editor = true;
          };
        };
      }
      (env.selectPlatform {
        linux = {
          my = {
            programs = {
              rtk.enable = true;
              hunk.enable = true;
              kitty.enable = true;
            };
            scripts.bun.enable = true;
          };
        };
      })
    ]
  );
}
