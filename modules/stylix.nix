# Stylix config, see: https://www.youtube.com/watch?v=ljHkWgBaQWU
{ pkgs, ... }:
{
  stylix = {
    enable = true;

    # base16Scheme = { };

    image = pkgs.fetchurl {
      # Blue starfield ship at Neon:
      # url= "https://pixeldrain.com/api/file/UELyHDVS";
      # sha256 = "";
      # Skyrim + Alduin:
      # url = "https://wallpaper.forfun.com/fetch/d8/d805db11e6dcb9262194536e29e44079.jpeg";
      # sha256 = "sha256-wI0jwjkNiQk3DWURM4AA2KBSxxn6Wc/5PaewlNNOojM=";
      # Starfield ship looking up:
      url = "https://pixeldrain.com/api/file/CWZC2L9b";
      sha256 = "sha256-m8c4ulgOQGBjNcCzW2RNJcLN9ewicFW1CIyHbG3+wmA=";
    };

    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 24;
    };

    # Force dark theme:
    # polarity = "dark";

    # fonts = {};
  };
}
