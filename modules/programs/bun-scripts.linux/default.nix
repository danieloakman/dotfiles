# Adds the co-located bun-scripts package to systemPackages.
{ pkgs, lib, config, bun2nix, ... }:
let
  bunScriptsPackage = pkgs.callPackage ./_package.nix { inherit bun2nix; };
in
{
  options.my.programs.bun-scripts.enable = lib.mkEnableOption "Enable the bun-scripts package";

  config = lib.mkIf config.my.programs.bun-scripts.enable {
    environment.systemPackages = [ bunScriptsPackage ];
  };
}
