{ env, ... }:
{
  # Enables blueman which is a Bluetooth manager GUI, which is needed in hyprland which has no built in bluetooth GUI.
  services.blueman.enable = true;
  home-manager.users.${env.user}.services.blueman-applet.enable = true;
}
