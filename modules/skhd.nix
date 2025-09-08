{ env, lib, pkgs, ... }:
let
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
      services.skhd = {
        enable = true;
        outLogFile = "/tmp/skhd.log";
        errorLogFile = "/tmp/skhd-error.log";
        config = ''
          alt - 1 : ${openApp}/bin/open-app "Vivaldi"
          alt - 2 : ${openApp}/bin/open-app "Cursor"
          alt - 3 : ${openApp}/bin/open-app "Microsoft Teams"
          alt - 4 : ${openApp}/bin/open-app "Roam"
          alt - 5 : ${openApp}/bin/open-app "zoom.us"
        '';
      };
    };
  };
}
