{ env, lib, config, ... }:
let
  cfg = config.my.desktop.phosh;
in
{
  options.my.desktop.phosh.enable = lib.mkEnableOption "Phosh mobile shell.";

  config = lib.mkIf cfg.enable {
    services.xserver.desktopManager.phosh = {
      enable = true;
      user = env.user;
      group = "users";
    };
  };
}
