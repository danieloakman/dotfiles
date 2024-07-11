# Stylix config, see: https://www.youtube.com/watch?v=ljHkWgBaQWU
{ pkgs, ... }:
{
  stylix = {
    enable = true;

    # base16Scheme = { };


    image = ../imgs/starfield_art_bay-topaz-enhance-2.5x.jpeg;

    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
    };

    # Force dark theme:
    polarity = "dark";

    # fonts = {};
  };
}
