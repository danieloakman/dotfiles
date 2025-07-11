# This module is used to set the keybinds for the gnome desktop environment.
{ lib, config, pkgs, ... }:
let
  mediaKeys = "org/gnome/settings-daemon/plugins/media-keys";
  customKeybindings = "${mediaKeys}/custom-keybindings";
  # Declare keybinds here:
  keybinds = [
    {
      # TODO: figure out why these rofi commands don't work on wayland
      name = "Emoji Picker";
      command = "rofi -show emoji";
      binding = "<Super>g";
    }
    {
      name = "Rofi Google Search";
      command = "rofi-google-search";
      binding = "<Super>s";
    }
    {
      name = "Rofi Run";
      # TODO: this is not working on wayland
      command = "rofi -show combi -combi-modi \"window,drun,run\" -modi combi";
      binding = "<Super>space";
    }
    {
      name = "Search Passwords";
      command = "zsh -c \"source ~/.zshrc && st -- passs -c\"";
      binding = "<Super>q";
    }
    {
      name = "Search & Kill Process";
      command = "kill-processes";
      binding = "<Super>k";
    }
    {
      name = "Move Mouse";
      command = "zsh -c \"source ~/.zshrc && st -- move-mouse\"";
      binding = "<Super><Alt>m";
    }
  ] ++ (if config.env.isOnWayland then [
    {
      name = "Toggle Open/Close Guake";
      command = "zsh -c \"guake-toggle\"";
      binding = "<Control>grave";
    }
  ] else [ ]);
in
{
  home-manager.users.${config.env.user} = {
    dconf.settings = {
      ${mediaKeys} = {
        custom-keybindings = lib.imap1 (i: keybind: "/${customKeybindings}/custom${toString i}/") keybinds;
      };
    } // lib.listToAttrs (lib.imap1
      (i: keybind: {
        name = "${customKeybindings}/custom${toString i}";
        value = keybind;
      })
      keybinds);

    home.packages = with pkgs; [
      # Simple terminal for faster startup time
      st

      # A script to reload the keybinds without a restart/logout-login
      (writeShellScriptBin "reload-keybinds" ''
        dconf reset -f /${customKeybindings}/
        dconf load /${mediaKeys}/ < ~/.config/dconf/keybinds.ini
      '')
      # Lists all custom keybinds and their settings. Useful for debugging and adding new keybinds.
      # Create a new keybind through the gnome custom keybinds interface, then run this script to get the settings and how the binding is set.
      (writeShellScriptBin "list-custom-keybinds" ''
        for i in {0..7}; do echo "=== custom$i ==="; dconf read /${customKeybindings}/custom$i/name; dconf read /${customKeybindings}/custom$i/command; dconf read /${customKeybindings}/custom$i/binding; echo; done
      '')
    ];
  };
}
