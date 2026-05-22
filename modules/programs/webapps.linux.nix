{ lib, config, env, pkgs, ... }:
let
  hyprlandEnabled = config.my.desktop.hyprland.enable;
  cfg = config.my.programs.webapps;
  uwsmCmd = lib.getExe pkgs.uwsm;
  vivaldiExe = lib.getExe pkgs.vivaldi;

  # Absolute paths under Adwaita so .desktop Icon= resolves without relying on theme lookup
  # (e.g. minimal XDG_DATA_DIRS under greetd → Hyprland).
  adw = "${pkgs.adwaita-icon-theme}/share/icons/Adwaita";
  webappIcons = {
    address-book = "${adw}/symbolic/mimetypes/x-office-address-book-symbolic.svg";
    bookmark = "${adw}/symbolic/actions/bookmark-new-symbolic.svg";
    calendar = "${adw}/symbolic/mimetypes/x-office-calendar-symbolic.svg";
    chat = "${adw}/symbolic/actions/chat-message-new-symbolic.svg";
    cloud-drive = "${adw}/symbolic/places/folder-remote-symbolic.svg";
    documents = "${adw}/symbolic/mimetypes/x-office-document-symbolic.svg";
    executable = "${adw}/symbolic/mimetypes/application-x-executable-symbolic.svg";
    folder = "${adw}/symbolic/places/folder-symbolic.svg";
    folder-pictures = "${adw}/symbolic/places/folder-pictures-symbolic.svg";
    games = "${adw}/symbolic/categories/applications-games-symbolic.svg";
    help = "${adw}/symbolic/legacy/help-browser-symbolic.svg";
    mail = "${adw}/symbolic/actions/mail-message-new-symbolic.svg";
    maps = "${adw}/symbolic/actions/find-location-symbolic.svg";
    music = "${adw}/symbolic/mimetypes/audio-x-generic-symbolic.svg";
    network = "${adw}/symbolic/legacy/preferences-system-network-symbolic.svg";
    package = "${adw}/symbolic/mimetypes/package-x-generic-symbolic.svg";
    photos = "${adw}/symbolic/mimetypes/image-x-generic-symbolic.svg";
    search = "${adw}/symbolic/legacy/preferences-system-search-symbolic.svg";
    settings = "${adw}/symbolic/categories/preferences-system-symbolic.svg";
    spreadsheet = "${adw}/symbolic/mimetypes/x-office-spreadsheet-symbolic.svg";
    terminal = "${adw}/symbolic/legacy/utilities-terminal-symbolic.svg";
    user-profile = "${adw}/symbolic/places/user-home-symbolic.svg";
    video = "${adw}/symbolic/mimetypes/video-x-generic-symbolic.svg";
    web-browser = "${adw}/symbolic/legacy/web-browser-symbolic.svg";
  };
  webappIconIds = lib.attrNames webappIcons;

  # Desktop Exec= must not embed raw URLs: `&`, `?`, quotes break when launchers run the line
  # through a shell. A tiny wrapper passes the URL as a single argv via escapeShellArg.
  mkWebappLauncher = entryName: url:
    pkgs.writeShellApplication {
      name = "webapp-${lib.strings.sanitizeDerivationName entryName}";
      text = ''
        exec ${uwsmCmd} app -- ${vivaldiExe} --ozone-platform=wayland --app=${lib.escapeShellArg url}
      '';
    };
in
{
  options.my.programs.webapps = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          url = lib.mkOption {
            type = lib.types.str;
            description = "The URL of the webapp (e.g. https://www.youtube.com)";
          };
          icon = lib.mkOption {
            type = lib.types.enum webappIconIds;
            default = "web-browser";
            description = ''
              Launcher icon preset; each value maps to a known Adwaita symbolic SVG path.

              Available: ${lib.concatStringsSep ", " webappIconIds}
            '';
          };
          categories = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "Network" "WebBrowser" ];
            description = "The categories of the webapp. Defaults to [ 'Network' 'WebBrowser' ].";
          };
        };
      }
    );
    default = { };
    description = "A map of webapps to add as a desktop entry with vivaldi.";
  };

  config = lib.mkMerge [
    (lib.mkIf hyprlandEnabled {
      home-manager.users.${env.user}.xdg.desktopEntries = lib.mapAttrs
        (
          name: value:
            let
              launcher = mkWebappLauncher name value.url;
            in
            {
              name = name;
              exec = lib.getExe launcher;
              categories = value.categories;
              icon = webappIcons.${value.icon};
              startupNotify = true;
            }
        )
        cfg;
    })
    # Add other webapp desktop entries here that don't use uwsm (when needed):
  ];
}
