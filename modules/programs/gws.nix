# Module for Google Workspace CLI tools, gmail, g-calendar, drive, etc.
#
# Auth on headless hosts (e.g. mara): interactive `gws auth login` is awkward on a
# server, so credentials are exported from a desktop machine and synced via Syncthing.
# Run `gws-auth-store` after logging in locally; wrapped `gws` reads the synced file.
#
# OAuth refresh tokens expire after 7 days when the GCP OAuth consent screen is External
# + Testing (Google's rule for sensitive scopes like Gmail/Calendar/Drive).
#
# Publishing to In production removes that 7-day limit for newly issued tokens. You must
# re-auth after publishing — an existing token from Testing mode keeps its original expiry.
#   1. Find the project in ~/.config/gws/client_secret.json (project_id) or Cloud Console.
#   2. OAuth consent screen → set publishing status to In production (Publish app).
#      Personal single-user use does not require full verification; expect an
#      "Unverified app" warning on login. Workspace orgs may prefer User type Internal.
#   3. Re-auth and re-export so mara gets a production-era refresh token:
#        gws auth login && gws-auth-store
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
  gwsSkillsSrc =
    (pkgs.fetchFromGitHub {
      # https://github.com/googleworkspace/cli/tree/a3768d0e82ad83cca2da97724e46bea4ff0e6dbd/skills
      owner = "googleworkspace";
      repo = "cli";
      rev = "a3768d0e82ad83cca2da97724e46bea4ff0e6dbd";
      sha256 = "sha256-YyNIHbyZrLlXYtWxZY8Um19MsnLharmS+nWGWO89fsA=";
    })
    + "/skills";
  # Gateway skill: registering ~70 sub-skills at the top level bloats every Claude
  # session's startup context. Instead, expose a single "gws" umbrella whose body
  # indexes the sub-skills (still on disk under ~/.claude/gws-skills/ but not
  # auto-discovered). Claude reads the umbrella on demand and Read's the relevant
  # sub-skill SKILL.md when needed.
  gwsUmbrella = pkgs.runCommand "gws-umbrella-skill" { } ''
    mkdir -p $out
    {
      echo '---'
      echo 'name: gws'
      echo 'description: "Google Workspace gateway (Gmail, Drive, Calendar, Docs, Sheets, Chat, Meet, Forms, Tasks, Slides, Apps Script, Classroom, Keep, People, Admin). Load this skill first to access the indexed sub-skills."'
      echo '---'
      echo ""
      echo '# Google Workspace skills'
      echo ""
      echo 'Sub-skills are installed at `~/.claude/gws-skills/`. They are NOT auto-discovered as skills to keep the global skill list small. To use one, Read the relevant SKILL.md path below and follow its instructions.'
      echo ""
      echo '## Index'
      echo ""
      for dir in ${gwsSkillsSrc}/*/; do
        name=$(basename "$dir")
        if [ -f "$dir/SKILL.md" ]; then
          desc=$(awk '/^description:/ { sub(/^description: */, ""); gsub(/^"|"$/, ""); print; exit }' "$dir/SKILL.md")
          echo "- **$name** — $desc"
          echo "  - \`~/.claude/gws-skills/$name/SKILL.md\`"
        fi
      done
    } > $out/SKILL.md
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
    my.programs.agents.skill-dirs.gws = gwsUmbrella;
    home-manager.users.${env.user}.home.file.".claude/gws-skills" = {
      source = gwsSkillsSrc;
      recursive = true;
    };
  };
}
