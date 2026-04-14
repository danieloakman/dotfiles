# Module for Google Workspace CLI tools, gmail, g-calendar, drive, etc.
{ pkgs, gws, system, env, ... }:
let
  gwsMcp = {
    command = "gws";
    args = [
      "mcp"
      "-s"
      "drive,gmail,calendar,tasks"
    ];
  };
in
{
  environment.systemPackages = with pkgs; [
    gws.packages.${system}.default
    google-cloud-sdk # Adds gcloud, which enables using `gws auth setup`
  ];
  # Fan-out to Cursor, Claude Code, and programs.mcp is handled in modules/dev/ai/config.nix.
  my.ai.mcp.gws = gwsMcp;
  home-manager.users.${env.user} = {
    programs.mcp.enable = true;
  };
}
