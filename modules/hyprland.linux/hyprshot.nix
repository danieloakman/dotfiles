{ env, pkgs, lib, config, ... }:
let
  cfg = config.my.programs.hyprshot;
  hyprshotExe = lib.getExe pkgs.hyprshot;
in
{
  options.my.programs.hyprshot.enable = lib.mkEnableOption "Enable the Hyprshot screenshot tool for Hyprland";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.my.desktop.hyprland.enable;
        message = "Hyprshot requires Hyprland to be enabled";
      }
    ];

    environment.systemPackages = [ pkgs.hyprshot ];

    home-manager.users.${env.user} = { lib, ... }: {
      home.activation.createHyprshotScreenshotDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p "$DRY_RUN_PREFIX${env.home}/Pictures/Screenshots"
      '';

      wayland.windowManager.hyprland.settings.bind = [
        ", Print, exec, ${hyprshotExe} -o ~/Pictures/Screenshots -m region"
      ];
    };
  };
}
