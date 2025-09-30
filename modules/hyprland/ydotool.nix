{ env, pkgs, ... }:
let
  group = "ydotool";
in
{
  environment.systemPackages = with pkgs; [
    ydotool
  ];
  programs.ydotool = {
    enable = true;
    inherit group;
  };
  users.users.${env.user}.extraGroups = [ group ];
}
