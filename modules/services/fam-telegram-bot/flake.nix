{
  description = "Family Telegram bot (expenses / calendar / tasks)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages.default = pkgs.callPackage ./_package.nix { };

        devShells.default = pkgs.mkShell {
          name = "fam-telegram-bot";
          packages = with pkgs; [
            cargo
            rustc
            rustfmt
            just
          ];
        };
      });
}
