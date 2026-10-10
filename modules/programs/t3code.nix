# T3 Code — minimal web GUI for coding agents.
# https://t3.codes
{ env, config, lib, ... }:
let
  cfg = config.my.programs.t3code;
in
{
  options.my.programs.t3code.enable = lib.mkEnableOption ''
    T3 Code (t3code): install via Home Manager's programs.t3code
  '';

  config = lib.mkIf cfg.enable {
    home-manager.users.${env.user}.programs.t3code.enable = true;
  };
}
