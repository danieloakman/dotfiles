# Evolution email and calendar app
{ pkgs, ... }:
{
  programs = {
    # This seemes to be the best all round email and calendar app for gnome.
    evolution = {
      enable = true;
      plugins = with pkgs; [
        evolution-ews # This https://kb.iu.edu/d/bghs was the only way I found to get connecting to my frogco email working, i.e. office365
      ];
    };
  };
}
