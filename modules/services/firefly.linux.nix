{ env, lib, config, ... }:
let
  cfg = config.my.services.firefly;
in
{
  options.my.services.firefly.enable = lib.mkEnableOption "Firefly III personal finance service.";

  config = lib.mkIf cfg.enable {
    services.firefly-iii = {
      enable = true;
      enableNginx = true;
      settings = {
        APP_KEY_FILE = "/home/${env.user}/Sync/secrets/firefly-3/app-key.txt";
      };
    };
  };
}
