# Herdr — terminal multiplexer for AI agents.
# https://herdr.dev
{ env, config, lib, ... }:
let
  cfg = config.my.programs.herdr;
  # tomlFormat = pkgs.formats.toml { };
in
{
  options.my.programs.herdr = {
    enable = lib.mkEnableOption ''
      Herdr (ogulcancelik/herdr): install and configure the agent terminal multiplexer
    '';

    # settings = lib.mkOption {
    #   inherit (tomlFormat) type;
    #   default = { };
    #   description = ''
    #     Herdr configuration written to `$XDG_CONFIG_HOME/herdr/config.toml`.
    #     See https://herdr.dev/docs/configuration/ for options.
    #   '';
    # };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${env.user} = {
      programs.herdr = {
        enable = true;
        # inherit (cfg) settings;
      };
    };
  };
}
