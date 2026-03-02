{ bun2nix, system, pkgs, lib, ... }:
let
  # See: https://nix-community.github.io/bun2nix/building-packages
  fetchBunDeps = bun2nix.packages.${system}.default.fetchBunDeps;
  hook = bun2nix.packages.${system}.default.hook;
in
{
  environment.systemPackages = [
    (pkgs.stdenv.mkDerivation {
      pname = "bun-scripts";
      version = "0.1.0";

      src = ./.;

      nativeBuildInputs = with pkgs; [
        hook
        bun
        makeWrapper
      ];

      bunDeps = fetchBunDeps {
        bunNix = ./bun.nix;
      };

      buildPhase = ''
        bun run build
      '';

      installPhase = ''
        mkdir -p $out/dist $out/bin
        cp -R ./dist/* $out/dist/
        for f in $out/dist/*.js; do
          name=$(basename "$f" .js)
          makeWrapper ${lib.getExe pkgs.bun} $out/bin/$name \
            --add-flags "run" --add-flags "$f" \
            --argv0 "$name"
        done
      '';
    })
  ];
}
