# This module is used to set the keybinds for the gnome desktop environment.
{ env, ... }:
let
  mediaKeys = "org/gnome/settings-daemon/plugins/media-keys";
  customKeybindings = "${mediaKeys}/custom-keybindings";
  # keybinds = [
  #   {
  #     path = "${customKeybindings}/custom0";
  #     name = "Emoji Picker";
  #     command = "rofi -show emoji";
  #     binding = "<Super>g";
  #   }
  # ];
in
{
  home-manager.users.${env.user}.dconf.settings = {
    ${mediaKeys} = {
      custom-keybindings = [
        "${customKeybindings}/custom0/"
      ];
    };

    "${customKeybindings}/custom0" = {
      name = "Emoji Picker";
      command = "rofi -show emoji";
      binding = "<Super>l";
    };
  };
}
