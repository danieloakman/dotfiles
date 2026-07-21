{ env, ... }:
{
  # Flake path is passed explicitly by justfile recipes (`{{ repo }}`), so we
  # intentionally leave programs.nh.flake unset. That avoids NH_FLAKE pointing at
  # a fixed checkout and breaking git worktrees.
  home-manager.users.${env.user}.programs.nh = {
    enable = true;
    clean = {
      enable = true;
      extraArgs = "--keep-since 14d --keep 3";
    };
  };
}
