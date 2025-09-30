{ env, ... }:
let
  group = "ydotool";
in
{
  programs.ydotool = {
    enable = true;
    inherit group;
  };
  users.users.${env.user}.extraGroups = [ group ];
}
