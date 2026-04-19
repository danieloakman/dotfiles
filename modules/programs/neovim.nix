# Neovim configuration:
# See: https://www.youtube.com/watch?v=YZAnJ0rwREA
# TODO
{ lib, config, env, ... }:
let
  cfg = config.my.programs.neovim;
in
{
  options.my.programs.neovim.enable = lib.mkEnableOption "Enable the Neovim editor along with its custom configuration.";

  config = lib.mkIf cfg.enable (env.selectPlatform {
    linux = {
      programs.neovim = {
        enable = true;
        viAlias = true;
        vimAlias = true;
      };
    };
    # Darwin not supported yet.
  });
}
