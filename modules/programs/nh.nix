{ env, ... }:
let
  cleanArgs = "--keep-since 14d --keep 3";
in
{
  # Flake path is passed explicitly by justfile recipes (`{{ repo }}`), so we
  # intentionally leave programs.nh.flake unset. That avoids NH_FLAKE pointing at
  # a fixed checkout and breaking git worktrees.
  #
  # Clean runs `nh clean all` on NixOS (system generations + store) and
  # `nh clean user` on Darwin via Home Manager until nix-darwin gains
  # programs.nh (https://github.com/nix-darwin/nix-darwin/pull/1744).
  config = env.selectPlatform {
    linux = {
      programs.nh = {
        enable = true;
        clean = {
          enable = true;
          extraArgs = cleanArgs;
        };
      };
    };
    darwin = {
      home-manager.users.${env.user}.programs.nh = {
        enable = true;
        clean = {
          enable = true;
          extraArgs = cleanArgs;
        };
      };
    };
  };
}
