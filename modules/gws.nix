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
        GOOGLE_WORKSPACE_CLI_CLIENT_ID = "$(cat ${config.sops.secrets.google_client_id.path})";
        GOOGLE_WORKSPACE_CLI_CLIENT_SECRET = "$(cat ${config.sops.secrets.google_client_secret.path})";
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
