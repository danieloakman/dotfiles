# Herdr — terminal multiplexer for AI agents.
# https://herdr.dev
{
  env,
  config,
  lib,
  ...
}:
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

  config = lib.mkIf cfg.enable (
    env.selectPlatform {
      linux = {
        home-manager.users.${env.user} = {
          programs.herdr = {
            enable = true;
            # https://herdr.dev/docs/configuration/#_top
            settings = {
              terminal.default_shell = "zsh";
              update.version_check = false;
              ui = {
                toast = {
                  delivery = "herdr";
                  herdr.position = "bottom-right";
                };
              };
            };
            # inherit (cfg) settings;
          };
        };
      };
      darwin = {
        homebrew.brews = [ "herdr" ];
      };
    }
  );
}
