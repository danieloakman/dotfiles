# Microsoft Apps
{ env, config, lib, ... }:
let
  cfg = config.my.programs.ms-apps;
in
{
  options.my.programs.ms-apps.enable = lib.mkEnableOption "Enable and add Microsoft Apps";

  config = lib.mkIf cfg.enable (env.selectPlatform {
    any = {
      # For now just prefer to use the webapp instead of the desktop app.
      # environment.systemPackages = with pkgs; [
      #   teams
      # ];
    };
    linux = {
      my.programs.webapps = {
        "Microsoft Teams" = {
          url = "https://teams.cloud.microsoft";
          icon = "folder-pictures";
          categories = [ "Network" "WebBrowser" ];
        };
        "Microsoft Outlook" = {
          url = "https://outlook.office.com";
          icon = "folder-pictures";
          categories = [ "Network" "WebBrowser" ];
        };
      };
    };
  });
}
