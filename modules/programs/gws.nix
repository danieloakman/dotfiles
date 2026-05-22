# Module for Google Workspace CLI tools, gmail, g-calendar, drive, etc.
{ pkgs, gws, system, lib, config, ... }:
let
  cfg = config.my.programs.gws;
  gwsExe = lib.getExe gws.packages.${system}.default;
  gwsAuthFile = config.sops.secrets."gws_auth.json".path;
  wrappedGws = pkgs.writeShellScriptBin "gws" ''
    export GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE=${gwsAuthFile}
    exec ${gwsExe} "$@"
  '';
in
{
  options.my.programs.gws.enable = lib.mkEnableOption "Enable the Google Workspace CLI tools, gmail, g-calendar, drive, etc.";

  config = lib.mkIf cfg.enable ({
    environment.systemPackages = with pkgs; [
      wrappedGws
      google-cloud-sdk # Adds gcloud, which enables using `gws auth setup`
    ];
    my.dev.ai.mcp.gws = {
      # TODO: this seems to be broken now for some reason.
      command = "gws";
      args = [
        "mcp"
        "-s"
        "drive,gmail,calendar,tasks"
      ];
    };
  });
}
