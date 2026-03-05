# Module for Google Workspace CLI tools, gmail, g-calendar, drive, etc.
{ pkgs, gws, system, env, config, ... }:
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
  programs.cursor-cli.mcpServers.gws = gwsMcp;
  home-manager.users.${env.user} = {
    home = {
      sessionVariables = {
        GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE = config.sops.secrets."gcloud_credentials.json".path;
        # TODO: see if we can add env vars that have a value like: $(pass api_keys/...)
      };
    };
    programs = {
      mcp = {
        enable = true;
        servers.gws = gwsMcp;
      };
      claude-code.mcpServers.gws = gwsMcp;
    };
  };
}
