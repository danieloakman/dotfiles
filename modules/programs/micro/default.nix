# https://home-manager-options.extranix.com/?query=micro&release=master
# VS Code keybindings: https://github.com/phil294/VSCode-keybindings-for-micro-editor-and-tty
{ env, config, lib, ... }:
let
  cfg = config.my.programs.micro;

  # VS Code / Cursor use Cmd on macOS and Ctrl on Linux.
  mod = env.selectPlatform {
    darwin = "Cmd";
    linux = "Ctrl";
  };

  bindingsText =
    let
      base = lib.replaceStrings [ "Ctrl" ] [ mod ] (builtins.readFile ./bindings.json);
    in
    env.selectPlatform {
      any = base;
      # Terminal escape sequences for Ctrl+Shift are Linux workarounds; use Cmd+Shift on macOS.
      darwin = lib.replaceStrings
        [
          ''"\u001b[112;6u": "CommandMode"''
          ''"\u001b[115;6u": "SaveAs"''
          ''"\u001b[107;6u": "DeleteLine"''
        ]
        [
          ''"CmdShift-p": "CommandMode"''
          ''"CmdShift-s": "SaveAs"''
          ''"CmdShift-k": "DeleteLine"''
        ]
        base;
    };
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
        "micro/bindings.json".text = bindingsText;
        "micro/init.lua".source = ./init.lua;
      };
    };
  };
}
