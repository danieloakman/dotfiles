# Hyprland module,
# See: https://www.youtube.com/watch?v=zt3hgSBs11g

{ pkgs, lib, inputs, ... }:
{
  programs.hyprland = {
    enable = true;
  };
}
