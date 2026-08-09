{ env, lib, config, ... }:
{
  options.my.desktop.hyprland.blueman.enable = lib.mkEnableOption "Enable the Blueman Bluetooth manager";
  # Enables blueman which is a Bluetooth manager GUI, which is needed in hyprland which has no built in bluetooth GUI.

  config = lib.mkIf config.my.desktop.hyprland.blueman.enable {
    services.blueman.enable = true;
    home-manager.users.${env.user}.services.blueman-applet.enable = true;
  };
}
