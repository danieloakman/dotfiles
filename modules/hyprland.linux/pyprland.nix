{ env, pkgs, lib, config, ... }:
let
  cfg = config.my.services.pyprland;
  startupScript = pkgs.writeShellScriptBin "pypr-start" ''
    ${pkgs.pyprland}/bin/pypr &

    sleep 1
  '';
in
{
  options.my.services.pyprland.enable = lib.mkEnableOption "Enable the Pyprland service";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.pyprland
      startupScript
    ];

    home-manager.users.${env.user} = {
      wayland.windowManager.hyprland.settings.exec-once = [
        lib.getExe
        startupScript
      ];

      home.file.".config/pypr/config.toml".text = ''
        [pyprland]
        terminal = "kitty"
      '';
    };
  };
}
