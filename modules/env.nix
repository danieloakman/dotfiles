# This module is used to configure the global system environment variables or options.
{ lib, config, ... }:

with lib;

let
  cfg = config.env;
in
{
  env = {
    user = mkOption {
      type = types.str;
      default = "dano";
      description = "Primary user name";
    };

    isLaptop = mkOption {
      type = types.bool;
      default = false;
      description = "Whether this is a laptop system";
    };

    isOnWayland = mkOption {
      type = types.bool;
      default = false;
      description = "Whether this system uses Wayland";
    };

    hasGPU = mkOption {
      type = types.bool;
      default = false;
      description = "Whether this system has a dedicated GPU";
    };

    wallpaper = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to the wallpaper image";
    };

    hyprland = mkOption {
      type = types.nullOr (types.submodule {
        options = {
          monitor = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Hyprland monitor configuration";
          };
        };
      });
      default = null;
      description = "Hyprland-specific monitor configuration";
    };
  };

  config = {
    # Make the env options available to other modules
    _module.args.env = cfg;
  };
}
