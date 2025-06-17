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
  ];
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
