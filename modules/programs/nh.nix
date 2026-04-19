{ env, ... }:
{
  home-manager.users.${env.user}.programs.nh = {
    enable = true;
    clean = {
      enable = true;
      extraArgs = "--keep-since 14d --keep 3";
    };
    flake = "${env.home}/repos/personal/dotfiles";
    darwinFlake = "${env.home}/repos/personal/dotfiles";
    homeFlake = "${env.home}/repos/personal/dotfiles";
  };
}
