# https://home-manager-options.extranix.com/?query=micro&release=master
{ env, config, lib, ... }:
let
  cfg = config.my.programs.micro;
in
{
  options.my.programs.micro.enable = lib.mkEnableOption "Enable micro, a terminal-based text editor.";

  config = lib.mkIf cfg.enable {
    home-manager.users.${env.user} = {
      programs.micro = {
        enable = true;
        settings = {
          autosu = true;
          backup = true;
          clipboard = "external";
          cursorline = true;
          matchbrace = true;
          permbackup = true;
          rmtrailingws = true;
          savecursor = true;
          saveundo = true;
          syntax = true;
        };
      };
    };
  };
}
