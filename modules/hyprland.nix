# Hyprland module for system level configuration.
# See: https://www.youtube.com/watch?v=zt3hgSBs11g

{ pkgs, inputs, ... }:
let
  startupScript = pkgs.pkgs.writeShellScriptBin "start" ''
    ${pkgs.waybar}/bin/waybar &
    ${pkgs.swww}/bin/swww init &
    ${pkgs.dunst}/bin/dunst &
    ${pkgs.rofi-wayland}/bin/rofi -show drun -show-icons &
    ${pkgs.kitty}/bin/kitty &

    sleep 1
  '';
  # ${pkgs.swww}/bin/swww img ${./wallpaper.png} &
  hyprPkgs = inputs.hyprland.packages."${pkgs.system}";
  hyprPlugins = inputs.hyprland-plugins.packages."${pkgs.system}";
in
{
  # Enable cachix for hyprland, otherwise hyprland will be built from source:
  nix.settings = {
    substituters = ["https://hyprland.cachix.org"];
    trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
  };

  environment.systemPackages = with pkgs; [
    # pyprland
    hyprpicker
    hyprcursor
    hyprlock
    hypridle
    # hyprpaper
    kitty
    rofi-wayland
    waybar
    dunst
    swww
  ];

  programs.hyprland = {
    enable = true;
    package = hyprPkgs.hyprland;
  };

  xdg.portal = {
    enable = true;
    # extraPortals = [
    #   hyprPkgs.xdg-desktop
    # ];
  };

  home-manager.users.dano = {
    wayland.windowManager.hyprland = {
      enable = true;
      package = hyprPkgs.hyprland;
      # systemd.variables = ["--all"];

      plugins = [
        hyprPlugins.borders-plus-plus
      ];

      settings = {
        exec-once = ''${startupScript}/bin/start'';

        "$mod" = "SUPER";

        # TODO: set monitor to not be so zoomed in, i.e. properly
        monitor="DP-1, 1920x1200, 0x0, 1.0";
        input = {
          natural_scroll = true;
          touchpad = {
            natural_scroll = true;
          };
        };

        "plugin:borders-plus-plus" = {
          add_borders = 1; # 0 - 9

          # you can add up to 9 borders
          "col.border_1" = "rgb(ffffff)";
          "col.border_2" = "rgb(2222ff)";

          # -1 means "default" as in the one defined in general:border_size
          border_size_1 = 10;
          border_size_2 = -1;

          # makes outer edges match rounding of the parent. Turn on / off to better understand. Default = on.
          natural_rounding = "yes";
        };
      };
    };
  };
}
