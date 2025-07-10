{
  description = "Main NixOS Flake";

  # See https://lazamar.co.uk/nix-versions/ for specific hashes to nixpkgs commits
  # Look for another website like this if this doesn't work like: 
  # https://www.nixhub.io/packages/
  inputs = {
    # nixpkgsStable.url = "github:nixos/nixpkgs/nixos-23.11";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    devenv.url = "github:cachix/devenv";
    openvpn24.url = "github:nixos/nixpkgs/2d38b664b4400335086a713a0036aafaa002c003";
    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };
    stylix.url = "github:danth/stylix";
    guake.url = "github:nixos/nixpkgs/5fd8536a9a5932d4ae8de52b7dc08d92041237fc"; # v3.9.0 works. v3.10 doesn't seem to appear in path or desktop apps.
    # zen-browser.url = "github:MarceColl/zen-browser-flake";
  };

  outputs = { self, nixpkgs, devenv, ... }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        # Just used for pkgs.fetchurl for now
        inherit system;
        config = {
          allowUnfree = true;
        };
      };
      createNixCache = _: {
        nix = {
          registry = {
            nixpkgs.flake = nixpkgs;
          };
          settings = {
            substituters = [
              "https://nix-community.cachix.org"
              "https://srid.cachix.org"
            ];
            trusted-public-keys = [
              "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
              "srid.cachix.org-1:MTQ6ksbfz3LBMmjyPh0PLmos+1x+CdtJxA/J2W+PQxI="
            ];
          };
        };
      };
      commonImports = { ... }: {
        # Imports inherit inputs system; used across all host configurations:
        imports = [
          ./modules/env.nix
          inputs.home-manager.nixosModules.home-manager
          ./modules/user.nix
          # TODO: import again once we actually use secrets from here
          # ./modules/secrets.nix
        ];
      };
    in
    {
      nixosConfigurations = {
        akatosh = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs system; };
          modules = [
            ./hosts/akatosh/configuration.nix
            commonImports
            { }
            createNixCache
            { }
          ];
        };
        azura = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs system; };
          modules = [
            ./hosts/azura/configuration.nix
            commonImports
            { }
            createNixCache
            { }
          ];
        };
        djo-tiny-laptop = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs system; };
          modules = [
            ./hosts/djo-tiny-laptop/configuration.nix
            commonImports
            { }
            createNixCache
            { }
          ];
        };
      };
      # packages.x86_64-linux.hello = nixpkgs.legacyPackages.x86_64-linux.hello;
      # packages.x86_64-linux.default = self.packages.x86_64-linux.hello;
    };
}
