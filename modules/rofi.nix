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
      plugins = with pkgs; [
        rofi-emoji
        # rofi-pass # Unmaintained. Using passmenu instead.
        # rofi-calc # I think just running node in terminal is easier for me.
        # rofi-file-browser # Would rather just use lf
        # rofi-screenshot # Would rather just use gnome-screenshot
      ];
      terminal = "${pkgs.gnome-console}/bin/gnome-console";
    };
  };
  environment.systemPackages = with pkgs; [
    # Specify this in gnome keyboard shortcuts or some other shortcut manager.
    (writeShellScriptBin "rofi-google-search" ''
      query=$(echo "" | ${rofi}/bin/rofi -dmenu -p "Google Search: ")
      if [ -n "$query" ]; then
        encoded_query=$(echo "$query" | sed 's/ /+/g')
        ${xdg-utils}/bin/xdg-open "https://www.google.com/search?q=$encoded_query"
      fi
    '')
  ];
}
