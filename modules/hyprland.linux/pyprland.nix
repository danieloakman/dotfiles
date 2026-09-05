{ env, pkgs, lib, config, ... }:
let
  cfg = config.my.desktop.hyprland.pyprland;
  startupScript = pkgs.writeShellScriptBin "pypr-start" ''
    ${pkgs.pyprland}/bin/pypr &

    sleep 1
  '';
in
{
  options.my.desktop.hyprland.pyprland.enable = lib.mkEnableOption "Enable the Pyprland service";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.pyprland
      startupScript
    ];

    home-manager.users.${env.user} = { lib, ... }:
      let
        hl = import ./_lua-lib.nix { inherit lib; };
      in
      {
        wayland.windowManager.hyprland.settings.on = [
          (hl.onStart [ (lib.getExe startupScript) ])
        ];

        home.file.".config/pypr/config.toml".text = ''
          [pyprland]
          terminal = "kitty"
        '';
      };
  };
}
