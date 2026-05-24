{ lib
, config
, env
, pkgs
, ...
}:
let
  cfg = config.my.programs.warp;
in
{
  options.my.programs.warp.enable = lib.mkEnableOption "Enable Warp terminal";

  config = lib.mkIf cfg.enable (
    env.selectPlatform {
      # any = {
      #   home-manager.${env.user}.home.files = {};
      # };

      linux = {
        environment.systemPackages = with pkgs; [ warp-terminal ];
      };

      darwin = {
        homebrew.casks = [ "warp" ];
      };
    }
  );
}
