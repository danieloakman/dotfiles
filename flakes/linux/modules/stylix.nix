# Stylix config, see: https://www.youtube.com/watch?v=ljHkWgBaQWU
{ inputs, pkgs, ... }:
{
  imports = [
    inputs.stylix.nixosModules.stylix
  ];

  stylix = {
    enable = true;

    # base16Scheme = { };

    # image = env.wallpaper; # Without this, `stylix.image` needs to be set in the host config
    # image = pkgs.fetchurl {
    #   # Skyrim + Alduin:
    #   url = "https://wallpaper.forfun.com/fetch/d8/d805db11e6dcb9262194536e29e44079.jpeg";
    #   sha256 = "sha256-wI0jwjkNiQk3DWURM4AA2KBSxxn6Wc/5PaewlNNOojM=";
    # };

    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 24;
    };

    # Force dark theme:
    polarity = "dark";

    # fonts = {};
  };
}
