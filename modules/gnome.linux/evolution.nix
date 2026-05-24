# Evolution email and calendar app
{ pkgs, lib, config, ... }:
{
  options.my = {
    programs.evolution.enable = lib.mkEnableOption "Enable the Evolution email and calendar app";
  };

  config = lib.mkIf config.my.programs.evolution.enable {
    programs = {
      # This seemes to be the best all round email and calendar app for gnome.
      evolution = {
        enable = true;
        plugins = with pkgs; [
          evolution-ews # This https://kb.iu.edu/d/bghs was the only way I found to get connecting to my frogco email working, i.e. office365
        ];
      };
    };
  };
}
