# https://home-manager-options.extranix.com/?query=micro&release=master
# VS Code keybindings: https://github.com/phil294/VSCode-keybindings-for-micro-editor-and-tty
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

          # Prefer the unofficial stable channel: main lists dead URLs (calc, mdtree, mxc)
          # that make micro print "Failed to decode repository data" on install.
          pluginchannels = [
            "https://raw.githubusercontent.com/Neko-Box-Coder/unofficial-plugin-channel/stable/channel.json"
            "https://raw.githubusercontent.com/micro-editor/plugin-channel/master/channel.json"
          ];
        };
      };

      xdg.configFile = {
        "micro/bindings.json".source = ./bindings.json;
        "micro/init.lua".source = ./init.lua;
      };
    };
  };
}
