# Lightweight remote desktop service for servers.
{ config, lib, pkgs, env, ... }:
let
  cfg = config.my.services.remote-desktop;
in
{
  options.my.services.remote-desktop = {
    enable = lib.mkEnableOption "Enable remote desktop services";
  };

  config = lib.mkIf cfg.enable (env.selectPlatform {
    linux = {
      services = {
        xserver = {
          enable = true;
          layout = "us";
          videoDrivers = [ "dummy" ];
          # Virtual resolution for headless (no physical monitor).
          monitorSection = ''
            Modeline "1920x1080" 173.00 1920 2048 2248 2576 1080 1083 1088 1120 -hsync +vsync
          '';
          screenSection = ''
            SubSection "Display"
              Depth 24
              Modes "1920x1080"
            EndSubSection
          '';
          displayManager.lightdm.enable = true;
          desktopManager.xfce = {
            enable = true;
            enableXfwm = true;
          };
        };
        xrdp = {
          enable = true;
          defaultWindowManager = "startxfce4";
          openFirewall = true;
        };
      };
      environment.systemPackages = with pkgs; [
        vivaldi
      ];
    };
    # Darwin not supported yet.
  });
}
