# Rofi is a launcher app that can be used to launch applications, files, and other items. Replacement for dmenu or ulauncher.
{ pkgs, config, ... }: {
  home-manager.users.${config.env.user} = {
    programs.rofi = {
      enable = true;
      location = "center";
      cycle = true;
      pass = {
        enable = true;
        stores = [
          "home/${config.env.user}/.local/share/password-store"
        ];
      };
      modes = [
        "emoji"
        "drun"
      ];
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
      # Create history file if it doesn't exist
      HISTORY_FILE="$HOME/.local/share/rofi-google-search-history"
      mkdir -p "$(dirname "$HISTORY_FILE")"
      touch "$HISTORY_FILE"

      # Display history and get user input
      query=$(cat "$HISTORY_FILE" | ${rofi}/bin/rofi -dmenu -p "Google Search: ")

      if [ -n "$query" ]; then
        # Add query to history file (if it's not already there)
        if ! grep -Fxq "$query" "$HISTORY_FILE"; then
          echo "$query" >> "$HISTORY_FILE"
        fi

        # Perform the search
        encoded_query=$(echo "$query" | sed 's/ /+/g')
        ${xdg-utils}/bin/xdg-open "https://www.google.com/search?q=$encoded_query"
      fi
    '')

    (writeShellScriptBin "kill-processes" ''
      # Get all running processes with CPU and memory usage, sorted by memory usage
      processes=$(ps -eo pid,pcpu,pmem,comm | sort -k3 -nr | awk '{printf "%-6s %5.1f%% %5.1f%% %s\n", $1, $2, $3, $4}')

      # Display processes in rofi
      selected_pid=$(echo "$processes" | ${rofi}/bin/rofi -dmenu -p "Kill Process: " | awk '{print $1}')

      # Kill the selected process
      if [ -n "$selected_pid" ]; then
        kill -9 "$selected_pid"
      fi
    '')
  ];
}
