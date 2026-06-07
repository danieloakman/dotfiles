{ lib
, pkgs
, config
, env
, ...
}:
let
  cfg = config.my.programs.cursor;
in
{
  options.my.programs.cursor.enable = lib.mkEnableOption "Enable the Cursor code editor";

  config = lib.mkIf cfg.enable (
    env.selectPlatform {
      linux = {
        environment.systemPackages = [
          pkgs.code-cursor
        ];
      };
      darwin.homebrew.casks = [
        "cursor"
        # "cursor-cli" # boethiah can't install and use this for some reason.
      ];
    }
  );
}
