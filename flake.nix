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
    # devenv.url = "github:cachix/devenv";
    openvpn24.url = "github:nixos/nixpkgs/2d38b664b4400335086a713a0036aafaa002c003";
    hyprland = {
      url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };
    hyprgrass = {
      url = "github:horriblename/hyprgrass";
      inputs.hyprland.follows = "hyprland";
    };
    stylix.url = "github:danth/stylix";
    guake.url = "github:nixos/nixpkgs/5fd8536a9a5932d4ae8de52b7dc08d92041237fc"; # v3.9.0 works. v3.10 doesn't seem to appear in path or desktop apps.
    astal.url = "github:aylur/astal";
    ags.url = "github:aylur/ags";
    # zen-browser.url = "github:MarceColl/zen-browser-flake";
  };

  outputs = { self, nixpkgs, ... }@inputs:
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
              "https://hyprland.cachix.org" # Enable cachix for hyprland, otherwise hyprland will be built from source
            ];
            trusted-substituters = [ "https://hyprland.cachix.org" ];
            trusted-public-keys = [
              "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
              "srid.cachix.org-1:MTQ6ksbfz3LBMmjyPh0PLmos+1x+CdtJxA/J2W+PQxI="
              "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
            ];
          };
        };
      };
      commonImports = { ... }: {
        # Imports inherit inputs system; used across all host configurations:
        imports = [
          inputs.home-manager.nixosModules.home-manager
          # This requires env, which is currently defined in the host/configuration.nix, so it can't be imported here (for now).
          # (import ./modules/system.nix { inherit lib inputs config pkgs env; })
          ./modules/user.nix
          ./modules/secrets.nix
          ./modules/kitty.nix
        ];
      };
      createEnv = { user, isLaptop, isOnWayland, hasGPU }: { inherit user isLaptop isOnWayland hasGPU; };
    in
    {
      nixosConfigurations = {
        akatosh = nixpkgs.lib.nixosSystem {
          specialArgs =
            let
              env = createEnv {
                user = "dano";
                isLaptop = false;
                isOnWayland = false;
                hasGPU = true;
              };
            in
            { inherit inputs system env; };
          modules = [
            ./hosts/akatosh/configuration.nix
            commonImports
            { }
            createNixCache
            { }
          ];
        };
        azura = nixpkgs.lib.nixosSystem {
          specialArgs =
            let
              env = createEnv {
                user = "dano";
                isLaptop = true;
                isOnWayland = true;
                hasGPU = false;
              };
            in
            { inherit inputs system env; };
          modules = [
            ./hosts/azura/configuration.nix
            commonImports
            { }
            createNixCache
            { }
          ];
        };
        djo-tiny-laptop = nixpkgs.lib.nixosSystem {
          specialArgs =
            let
              env = createEnv {
                user = "dano";
                isLaptop = true;
                isOnWayland = true;
                hasGPU = false;
              };
            in
            { inherit inputs system env; };
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
