# Module for Google Workspace CLI tools, gmail, g-calendar, drive, etc.
{ pkgs, gws, system, lib, config, ... }:
let
  cfg = config.my.programs.gws;
in
{
  options.my.programs.gws.enable = lib.mkEnableOption "Enable the Google Workspace CLI tools, gmail, g-calendar, drive, etc.";

  config = lib.mkIf cfg.enable ({
    environment.systemPackages = with pkgs; [
      gws.packages.${system}.default
      google-cloud-sdk # Adds gcloud, which enables using `gws auth setup`
    ];
    # Fan-out to Cursor, Claude Code, and programs.mcp is handled in modules/dev/ai/config.nix.
    my.dev.ai.mcp.gws = {
      command = "gws";
      args = [
        "mcp"
        "-s"
        "drive,gmail,calendar,tasks"
      ];
    };
  });
}
