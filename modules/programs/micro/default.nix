# https://home-manager-options.extranix.com/?query=micro&release=master
# VS Code keybindings: https://github.com/phil294/VSCode-keybindings-for-micro-editor-and-tty
{ env, config, lib, pkgs, ... }:
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

  # https://github.com/dmaluka/micro-detectindent
  # Pin to a release tag so sha256 stays stable until you bump rev.
  # To upgrade: set rev, then `nix flake prefetch github:dmaluka/micro-detectindent/<rev>`
  # and copy the printed hash into sha256.
  detectindentPlugin = pkgs.fetchFromGitHub {
    owner = "dmaluka";
    repo = "micro-detectindent";
    rev = "v1.1.1";
    sha256 = "sha256-XSNsfrw1xdfwnJfFI3n2DC7a6MK0X0GyB27m5+8HMl8=";
  };
in
{
  options.my.programs.micro = {
    enable = lib.mkEnableOption "Enable micro, a terminal-based text editor.";
    isDefaultEditor = lib.mkEnableOption "Make micro the default editor for the system.";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${env.user} = {
      home.sessionVariables = lib.mkIf cfg.isDefaultEditor {
        EDITOR = "micro";
        GIT_EDITOR = "micro";
      };

      programs = {
        micro = {
          enable = true;
          settings = {
            autosu = true;
            backup = true;
            clipboard = "external";
            cursorline = true;
            detectindent = true;
            diffgutter = true;
            matchbrace = true;
            permbackup = true;
            rmtrailingws = true;
            savecursor = true;
            saveundo = true;
            softwrap = true;
            syntax = true;
            # Fallback when detectindent can't infer (empty/new files).
            tabsize = 2;
            tabstospaces = true;

            # Prefer the unofficial stable channel: main lists dead URLs (calc, mdtree, mxc)
            # that make micro print "Failed to decode repository data" on install.
            pluginchannels = [
              "https://raw.githubusercontent.com/Neko-Box-Coder/unofficial-plugin-channel/stable/channel.json"
              "https://raw.githubusercontent.com/micro-editor/plugin-channel/master/channel.json"
            ];
          };
        };

        zsh = lib.mkIf cfg.isDefaultEditor {
          shellAliases = {
            "vim" = "micro";
            "nvim" = "micro";
            "editor" = "micro";
          };
          initContent = ''
            # Set the default editor to micro
            export EDITOR="micro"
            export GIT_EDITOR="micro"
          '';
        };
      };

      xdg.configFile = {
        "micro/bindings.json".text = bindingsText;
        "micro/init.lua".source = ./init.lua;
        "micro/plug/detectindent".source = detectindentPlugin;
      };
    };
  };
}
