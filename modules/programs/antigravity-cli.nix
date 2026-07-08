# Google Antigravity CLI — terminal interface for Antigravity agents.
# https://antigravity.google/docs/cli-getting-started
{ env
, config
, lib
, pkgs
, ...
}:
let
  cfg = config.my.programs.antigravity-cli;
in
{
  options.my.programs.antigravity-cli.enable = lib.mkEnableOption ''
    Google Antigravity CLI (agy): terminal interface for Antigravity agents
  '';

  config = lib.mkIf cfg.enable (
    env.selectPlatform {
      linux = {
        environment.systemPackages = [ pkgs.antigravity-cli ];
      };
      darwin = {
        homebrew.casks = [ "antigravity-cli" ];
      };
    }
  );
}
