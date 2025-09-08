{ env, lib, pkgs, ... }:
let
  listDockedApps = pkgs.writeShellScriptBin "list-docked-apps" ''
    osascript -e 'tell application "System Events" to tell process "Dock" to set DL to name of UI elements of list 1 whose subrole is "AXApplicationDockItem"' | sed 's/ *, */\n/g'
  '';
  openApp = pkgs.writeShellScriptBin "open-app" ''
    APP_NAME="$1"

    # Check if app is running
    if pgrep -x "$APP_NAME" > /dev/null; then
        # Check if app is frontmost
        FRONTMOST=$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true')

        if [ "$FRONTMOST" = "$APP_NAME" ]; then
            # App is focused, hide it
            osascript -e "tell application \"System Events\" to set visible of process \"$APP_NAME\" to false"
        else
            # App is running but not focused, bring to front
            osascript -e "tell application \"$APP_NAME\" to activate"
        fi
    else
        # App is not running, launch it
        open -a "$APP_NAME"
    fi
  '';
  openDockedApp = pkgs.writeShellScriptBin "open-docked-app" ''
    N="$1"
    APP_NAME=$(${listDockedApps}/bin/list-docked-apps | sed -n "$N"p)
    ${openApp}/bin/open-app $APP_NAME
  '';
in
{
  config = lib.mkIf pkgs.stdenv.isDarwin {
    # services.skhd = {
    #   enable = true;
    #   skhdConfig = ''
    #     alt - 1 : open -a "Vivaldi"
    #     alt - 2 : open -a "Cursor"
    #     alt - 3 : ${openApp}/bin/open-app "Microsoft Teams"
    #     alt - 4 : ${openApp}/bin/open-app "Roam"
    #     alt - 5 : ${openApp}/bin/open-app "zoom.us"
    #   '';
    # };

    home-manager.users.${env.user} = {
      home.packages = [ openApp listDockedApps openDockedApp ];
      services.skhd = {
        enable = true;
        outLogFile = "/tmp/skhd.log";
        errorLogFile = "/tmp/skhd-error.log";
        config = ''
          alt - t : open-docked-app 1
          alt - 1 : open-docked-app 2
          alt - 2 : open-docked-app 3
          alt - 3 : open-docked-app 4
          alt - 4 : open-docked-app 5
          alt - 5 : open-docked-app 6
          alt - 6 : open-docked-app 7
          alt - 7 : open-docked-app 8
          alt - 8 : open-docked-app 9
          alt - 9 : open-docked-app 10
          alt - 0 : open-docked-app 11
        '';
      };
    };
  };
}
