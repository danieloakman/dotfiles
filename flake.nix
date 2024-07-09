{
  description = "Main NixOS Flake";

  # See https://lazamar.co.uk/nix-versions/ for specific hashes to nixpkgs commits
  # Look for another website like this if this doesn't work
  inputs = {
    # nixpkgsStable.url = "github:nixos/nixpkgs/nixos-23.11";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    devenv.url = "github:cachix/devenv";
    openvpn24.url = "github:nixos/nixpkgs/2d38b664b4400335086a713a0036aafaa002c003";
    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };
  };

  outputs = { self, nixpkgs, devenv,... }@inputs:
    let
      system = "x86_64-linux";
      # pkgs = import nixpkgs {
      #   inherit system;

      #   config = {
      #     allowUnfree = true;
      #   };
      # };
      createNixCache = ({ ... }: {
        # nix = {
        #   registry = {
        #     nixpkgs.flake = nixpkgs;
        #   };
        #   settings = {
        #     substituters = [
        #       "https://nix-community.cachix.org"
        #       "https://srid.cachix.org"
        #     ];
        #     trusted-public-keys = [
        #       "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        #       "srid.cachix.org-1:MTQ6ksbfz3LBMmjyPh0PLmos+1x+CdtJxA/J2W+PQxI="
        #     ];
        #   };
        # };
      });
    in
    {
      nixosConfigurations = {
        djo-personal-desktop = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs system; };
          modules = [
            ./hosts/djo-personal-desktop/configuration.nix
            createNixCache {}
          ];
        };
        djo-personal-laptop = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs system; };
          modules = [
            ./hosts/djo-personal-laptop/configuration.nix
            createNixCache {}
          ];
        };
        djo-tiny-laptop = nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs system; };
          modules = [
            ./hosts/djo-tiny-laptop/configuration.nix
            createNixCache {}
          ];
        };
      };
      # packages.x86_64-linux.hello = nixpkgs.legacyPackages.x86_64-linux.hello;
      # packages.x86_64-linux.default = self.packages.x86_64-linux.hello;
    };
}
