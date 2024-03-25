# Development stuff for mobile dev:
{ pkgs, ... }:
{
  programs = {
    # Enable Android Debug Bridge:
    adb.enable = true;
  };
  environment.systemPackages = with pkgs; [
    android-studio
    android-tools
  ];
}