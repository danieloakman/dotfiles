{ env, config, pkgs, lib, ... }:
let
  gcalcliSkillPath = ../files/ai/skills/gcalcli.md;
  gcalcliExe = lib.getExe pkgs.gcalcli;
in
{
  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "gcalcli" ''
      ${env.selectPlatform {
        darwin = ''
          CLIENT_ID=$(pass api_keys/personal/google_credentials/google_calendar_mcp/client_id)
          CLIENT_SECRET=$(pass api_keys/personal/google_credentials/google_calendar_mcp/client_secret)
        '';
        linux = ''
          CLIENT_ID=$(cat ${config.sops.secrets.google_client_id.path})
          CLIENT_SECRET=$(cat ${config.sops.secrets.google_client_secret.path})
        '';
      }}
      exec ${gcalcliExe} --client-id "$CLIENT_ID" --client-secret "$CLIENT_SECRET" "$@"
    '')
  ];
  home-manager.users.${env.user} = {
    # Add AI Skills for gcalcli:
    home.file.".cursor/skills/gcalcli".source = gcalcliSkillPath;
    programs.claude-code.skills.gcalcli = gcalcliSkillPath;
  };
}
