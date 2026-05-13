{
  lib,
  pkgs,
  config,
  env,
  ...
}:
let
  cfg = config.my.programs.cursor;
  cursor-cli = pkgs.writeShellScriptBin "cursor-cli" ''
    CURSOR_API_KEY="$(cat ${config.sops.secrets.cursor_api_key.path})"
    ${lib.getExe pkgs.code-cursor} --api-key "$CURSOR_API_KEY" "$@"
  '';
in
{
  options.my.programs.cursor.enable = lib.mkEnableOption "Enable the Cursor code editor";

  config = lib.mkIf cfg.enable (
    env.selectPlatform {
      linux = {
        environment.systemPackages = [
          pkgs.code-cursor
          cursor-cli
          (pkgs.writeShellScriptBin "open-cursor" ''
            # Opens the cursor editor in the current directory
              ${lib.getExe pkgs.code-cursor} . &> /tmp/cursor.log &
          '')
        ];
      };
      # TODO: migrate cursor config from boethiah to here.
      darwin.homebrew.casks = [
        "cursor"
        "cursor-cli"
      ];
    }
  );
}
