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
    my.dev.ai.skillDirs.gws =
      (pkgs.fetchFromGitHub {
        # https://github.com/googleworkspace/cli/tree/a3768d0e82ad83cca2da97724e46bea4ff0e6dbd/skills
        owner = "googleworkspace";
        repo = "cli";
        rev = "a3768d0e82ad83cca2da97724e46bea4ff0e6dbd";
        sha256 = "sha256-YyNIHbyZrLlXYtWxZY8Um19MsnLharmS+nWGWO89fsA=";
      })
      + "/skills";
  });
}
