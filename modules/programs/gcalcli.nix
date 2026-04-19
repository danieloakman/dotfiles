# Google Calendar CLI tool.
{ env, config, pkgs, lib, ... }:
let
  cfg = config.my.programs.gcalcli;
  gcalcliSkillPath = ../files/ai/skills/gcalcli.md;
  gcalcliExe = lib.getExe pkgs.gcalcli;
in
{
  options.my.programs.gcalcli.enable = lib.mkEnableOption "Enable the Google Calendar CLI tool (gcalcli).";

  config = lib.mkIf cfg.enable ({
    environment.systemPackages = with pkgs; [
      (writeShellScriptBin "gcalcli" ''
        ${env.selectPlatform {
          darwin = ''
            CLIENT_ID=$(pass api_keys/personal/google_credentials/gws/client_id)
            CLIENT_SECRET=$(pass api_keys/personal/google_credentials/gws/client_secret)
          '';
          linux = ''
            CLIENT_ID=$(cat ${config.sops.secrets.google_client_id.path})
            CLIENT_SECRET=$(cat ${config.sops.secrets.google_client_secret.path})
          '';
        }}
        exec ${gcalcliExe} --client-id "$CLIENT_ID" --client-secret "$CLIENT_SECRET" "$@"
      '')
    ];
    my.dev.ai.skills.gcalcli = gcalcliSkillPath;
  });
}
