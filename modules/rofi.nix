# Rofi is a launcher app that can be used to launch applications, files, and other items. Replacement for dmenu or ulauncher.
{ pkgs, env, ... }: {
  home-manager.users.${env.user} = {
    home = {
      packages = with pkgs; [
        rofi
      ];
    };

    programs.rofi = {
      enable = true;
      theme = "Nord";
      font = "Iosevka 14";
      location = "center";
      cycle = true;
      pass = {
        enable = true;
      };
      plugins = with pkgs; [
        rofi-pass
        rofi-calc
        rofi-emoji
        rofi-file-browser
        rofi-screenshot
      ];
      terminal = "${pkgs.gnome.gnome-console}/bin/gnome-console";
    };
  };
}
