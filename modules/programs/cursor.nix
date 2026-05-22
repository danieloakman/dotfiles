{ lib
, pkgs
, config
, env
, ...
}:
let
  cfg = config.my.programs.cursor;
  cursor-cli = pkgs.writeShellScriptBin "cursor-cli" ''
    ${env.selectPlatform {
      darwin = ''
        CURSOR_API_KEY=$(pass api_keys/personal/cursor_ai)
      '';
      linux = ''
        CURSOR_API_KEY="$(cat ${config.sops.secrets.cursor_api_key.path})"
      '';
    }}
    ${lib.getExe pkgs.code-cursor} --api-key "$CURSOR_API_KEY" "$@"
  '';
in
{
  options.my.programs.cursor.enable = lib.mkEnableOption "Enable the Cursor code editor";

  config = lib.mkIf cfg.enable (
    env.selectPlatform {
      any = {
        environment.systemPackages = [
          cursor-cli
        ];
      };
      linux = {
        environment.systemPackages = [
          pkgs.code-cursor
          # TODO: see if this script is still necessary on linux. Reason its here is because logs would be spewed out every time `cursor` was used from cli
          (pkgs.writeShellScriptBin "open-cursor" ''
            # Opens the cursor editor in the current directory
              ${lib.getExe pkgs.code-cursor} . &> /tmp/cursor.log &
          '')
        ];
      };
      darwin.homebrew.casks = [
        "cursor"
        # "cursor-cli" # boethiah can't install and use this for some reason.
      ];
    }
  );
}
