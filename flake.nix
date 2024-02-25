{
  description = "Main NixOS Flake";

  inputs = {
    # nixpkgsStable.url = "github:nixos/nixpkgs/nixos-23.11";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    devenv.url = "github:cachix/devenv";
    nix-ld = {
      url = "github:Mic92/nix-ld";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    openvpn24.url = "github:nixos/nixpkgs/2d38b664b4400335086a713a0036aafaa002c003";
  };

  outputs = { self, nixpkgs, devenv, nix-ld, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;

        config = {
          allowUnfree = true;
        };
      };
    in
    {
      nixosConfigurations = {
        djo-personal-desktop = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs system; };
          modules = [
            ./hosts/djo-personal-desktop/configuration.nix
            nix-ld.nixosModules.nix-ld
          ];
        };
        djo-personal-laptop = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs system; };
          modules = [
            ./hosts/djo-personal-laptop/configuration.nix
            nix-ld.nixosModules.nix-ld
          ];
        };
        djo-tiny-laptop = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs system; };
          modules = [
            ./hosts/djo-tiny-laptop/configuration.nix
            nix-ld.nixosModules.nix-ld
          ];
        };
      };
      # packages.x86_64-linux.hello = nixpkgs.legacyPackages.x86_64-linux.hello;
      # packages.x86_64-linux.default = self.packages.x86_64-linux.hello;
    };
}
