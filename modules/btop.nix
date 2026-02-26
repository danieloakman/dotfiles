{ env, pkgs, ... }:
let
  package = if env.hasGPU then pkgs.btop-cuda else pkgs.btop;
in
{
  home-manager.users.${env.user} = {
    programs.btop = {
      inherit package;
      enable = true;
      # settings.color_theme = "catppuccin";
    };
  };
}
