# This module is used to set the keybinds for the gnome desktop environment.
{ lib, env, ... }:
let
  mediaKeys = "org/gnome/settings-daemon/plugins/media-keys";
  customKeybindings = "${mediaKeys}/custom-keybindings";
  # Declare keybinds here:
  keybinds = [
    {
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
      command = "rofi -show combi -combi-modi \"window,drun,run\" -modi combi";
      binding = "<Super>space";
    }
    {
      name = "Search Passwords";
      command = "zsh -c \"source ~/.zshrc && gnome-terminal -- passs -c\"";
      binding = "<Super>q";
    }
    {
      name = "Search & Kill Process";
      command = "kill-processes";
      binding = "<Super>k";
    }
    {
      name = "Move Mouse";
      command = "zsh -c \"source ~/.zshrc && gnome-terminal -- move-mouse\"";
      binding = "<Super><Alt>m";
    }
  ] ++ (if env.isOnWayland then [
    {
      name = "Toggle Open/Close Guake";
      command = "zsh -c \"guake-toggle\"";
      binding = "<Ctrl>`";
    }
  ] else [ ]);
in
{
  home-manager.users.${env.user}.dconf.settings = {
    ${mediaKeys} = {
      custom-keybindings = lib.imap1 (i: keybind: "/${customKeybindings}/custom${toString i}/") keybinds;
    };
  } // lib.listToAttrs (lib.imap1
    (i: keybind: {
      name = "${customKeybindings}/custom${toString i}";
      value = keybind;
    })
    keybinds);
}
