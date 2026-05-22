# NixOS module: adds the bun-scripts package (built by this dir's flake) to systemPackages.
# The host flake must pass bunScriptsPackage in specialArgs (e.g. from inputs.bun-scripts.packages.${system}.default).
{ bunScriptsPackage, lib, config, ... }:
{
  options.my.scripts.bun.enable = lib.mkEnableOption "Enable the bun-scripts package";

  config = lib.mkIf config.my.scripts.bun.enable {
    environment.systemPackages = [ bunScriptsPackage ];
  };
}
