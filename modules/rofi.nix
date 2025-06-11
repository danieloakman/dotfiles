# Rofi is a launcher app that can be used to launch applications, files, and other items. Replacement for dmenu or ulauncher.
{ pkgs, env, ... }: {
  home-manager.users.${env.user} = {
    programs.rofi = {
      enable = true;
      location = "center";
      cycle = true;
      pass = {
        enable = true;
        stores = [
          "home/${env.user}/.local/share/password-store"
        ];
      };
      modes = [
        "drun"
        "emoji"
        "filebrowser"
        "run"
        "screenshot"
        "ssh"
        "window"
        "combi"
        "calc"
      ];
      plugins = with pkgs; [
        rofi-pass
        rofi-calc
        rofi-emoji
        rofi-file-browser
        rofi-screenshot
      ];
      terminal = "${pkgs.gnome-console}/bin/gnome-console";
    };
  };
}
