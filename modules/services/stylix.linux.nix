# Stylix config, see: https://www.youtube.com/watch?v=ljHkWgBaQWU
# Linux-only for now: Darwin stylix mainly themes HM pkgs and was awkward to dual-load.
{ inputs, pkgs, lib, config, env, ... }:
let
  cfg = config.my.services.stylix;
  # In-repo attrs (not pkgs.base16-schemes) keep `nix flake check --no-build` working:
  # Stylix's image-derived default needs a built palette.json; a package path needs
  # the scheme output in the store. Both fail under --no-build on a cold machine.
  gruvboxDarkHard16 = {
    base00 = "1d2021";
    base01 = "3c3836";
    base02 = "504945";
    base03 = "665c54";
    base04 = "bdae93";
    base05 = "d5c4a1";
    base06 = "ebdbb2";
    base07 = "fbf1c7";
    base08 = "fb4934";
    base09 = "fe8019";
    base0A = "fabd2f";
    base0B = "b8bb26";
    base0C = "8ec07c";
    base0D = "83a598";
    base0E = "d3869b";
    base0F = "d65d0e";
  };
in
{
  imports = [ inputs.stylix.nixosModules.stylix ];

  options.my.services.stylix = {
    enable = lib.mkEnableOption "Enable the Stylix module for setting the wallpaper and theme of the desktop.";
    wallpaper = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "The wallpaper to use for the desktop.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = cfg.wallpaper != null;
      message = "Stylix requires a wallpaper to be set with `my.services.stylix.wallpaper`.";
    }];

    stylix = {
      enable = true;

      image = cfg.wallpaper;

      # Force dark theme:
      polarity = "dark";

      # fonts = {};

      cursor = {
        package = pkgs.bibata-cursors;
        name = "Bibata-Modern-Ice";
        size = 24;
      };
    } // lib.optionalAttrs (cfg.wallpaper == null) {
      # See gruvboxDarkHard16 in the let-binding: explicit scheme avoids Stylix's
      # generated-palette default (importJSON + runCommand) and avoids a pkgs
      # path that is not substituted under `nix flake check --no-build`.
      base16Scheme = gruvboxDarkHard16;
    };

    # Stylix's Qt target installs generated Kvantum themes via recursive xdg linking.
    # Stale store-backed theme paths block linkGeneration from moving files to .bak.
    home-manager.users.${env.user} = { lib, ... }: {
      home.activation.cleanupStylixKvantumThemes = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
        for theme in "$HOME/.config/Kvantum"/Base16*; do
          if [ -e "$theme" ]; then
            $DRY_RUN_CMD rm -rf "$theme"
          fi
        done
      '';
    };
  };
}
