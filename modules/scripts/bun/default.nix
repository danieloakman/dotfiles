# NixOS module: adds the bun-scripts package (built by this dir's flake) to systemPackages.
# The host flake must pass bunScriptsPackage in specialArgs (e.g. from inputs.bun-scripts.packages.${system}.default).
{ bunScriptsPackage, ... }:
{
  environment.systemPackages = [ bunScriptsPackage ];
}
