{
  description = "Bun scripts package and dev shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    bun2nix = {
      url = "github:nix-community/bun2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, bun2nix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        fetchBunDeps = bun2nix.packages.${system}.default.fetchBunDeps;
        hook = bun2nix.packages.${system}.default.hook;
        otherPackages = with pkgs; [
          # Other packages needed for the scripts:
          poppler-utils # Provides `pdftotext` command
          fzf
        ];
        mkPackage = pkgs.stdenv.mkDerivation {
          pname = "bun-scripts";
          version = "0.1.0";
          src = ./.;
          nativeBuildInputs = with pkgs; [ hook bun makeWrapper ] ++ otherPackages;
          bunDeps = fetchBunDeps { bunNix = ./bun.nix; };
          buildPhase = ''bun run build'';
          installPhase = ''
            mkdir -p $out/dist $out/bin
            cp -R ./dist/* $out/dist/
            cp -rL ./node_modules $out/node_modules
            for f in $out/dist/*.js; do
              name=$(basename "$f" .js)
              makeWrapper ${pkgs.lib.getExe pkgs.bun} $out/bin/$name \
                --add-flags "run" --add-flags "$f" \
                --set NODE_PATH "$out" \
                --set PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS true \
                --set PLAYWRIGHT_BROWSERS_PATH ${pkgs.playwright-driver.browsers} \
                --argv0 "$name"
            done
          '';
        };
      in
      {
        packages.default = mkPackage;
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            bun
            playwright-driver
          ] ++ otherPackages;
          NIX_BUILD_SHELL = "${pkgs.zsh}/bin/zsh";
          shellHook = ''
            export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true
            export PLAYWRIGHT_BROWSERS_PATH=${pkgs.playwright-driver.browsers}
          '';
        };
      }
    );
}
