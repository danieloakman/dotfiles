{ env, config, lib, ... }:
let
  cfg = config.my.programs.lf;
in
{
  # Prefer my.programs.superfile for day-to-day use; lf is the minimalist opt-in.
  options.my.programs.lf.enable = lib.mkEnableOption "Enable and configure lf.";

  config = lib.mkIf cfg.enable (env.selectPlatform {
    linux = {
      home-manager.users.${env.user} = {
        programs.lf = {
          enable = true;
          keybindings = {
            "D" = "delete";
            "~" = "cd ~";
          };
          # See https://github.com/gokcehan/lf/blob/master/doc.md#options
          settings = {
            hidden = true;
            info = [ "size" "time" ];
          };
        };
      };
    };
  });
}
