{ env, lib, config, ... }:
let
  cfg = config.my.programs.espanso;
in
{
  options.my.programs.espanso.enable = lib.mkEnableOption "Espanso text expander.";

  config = lib.mkIf cfg.enable {
    home-manager.users.${env.user}.services.espanso = {
      enable = true;
      matches = { };
    };
  };
}
