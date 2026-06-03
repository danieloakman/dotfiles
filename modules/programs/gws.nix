# Module for Google Workspace CLI tools, gmail, g-calendar, drive, etc.
{ pkgs, gws, system, lib, env, config, ... }:
let
  cfg = config.my.programs.gws;
  gwsExe = lib.getExe gws.packages.${system}.default;
  gwsCredentialsFile = "${env.home}/Sync/secrets/google/gws_credentials.json";
  wrappedGws = pkgs.writeShellScriptBin "gws" ''
    export GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE=${gwsCredentialsFile}
    exec ${gwsExe} "$@"
  '';
  gwsAuthStore = pkgs.writeShellScriptBin "gws-auth-store" ''
    set -euo pipefail
    creds=${gwsCredentialsFile}
    mkdir -p "$(dirname "$creds")"
    echo "Storing GWS credentials to $creds"
    # Export from local interactive auth (~/.config/gws), not the synced credentials file.
    unset GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE
    ${gwsExe} auth export --unmasked > "$creds.tmp"
    chmod 600 "$creds.tmp"
    mv "$creds.tmp" "$creds"
    echo "Wrote $creds (syncs via Syncthing general-sync folder)"
  '';
in
{
  options.my.programs.gws.enable = lib.mkEnableOption "Enable the Google Workspace CLI tools, gmail, g-calendar, drive, etc.";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      wrappedGws
      gwsAuthStore
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
  };
}
