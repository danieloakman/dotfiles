{
  description = "Main NixOS Flake";

  # Map package versions → nixpkgs commits:
  #   https://www.nixhub.io/packages/
  #   https://lazamar.co.uk/nix-versions/
  #   https://history.nix-packages.com/
  # Package search (often shows the nixpkgs revision): https://search.nixos.org/
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
    # hyprland = {
    #   # url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
    #   url = "github:nixos/nixpkgs/c633f572eded8c4f3c75b8010129854ed404a6ce";
    # };
    # hyprland-plugins = {
    #   url = "github:hyprwm/hyprland-plugins";
    #   inputs.hyprland.follows = "hyprland";
    # };
    # hyprgrass = {
    #   url = "github:horriblename/hyprgrass";
    #   # inputs.hyprland.follows = "hyprland";
    # };
    stylix.url = "github:danth/stylix";
    guake.url = "github:nixos/nixpkgs/5fd8536a9a5932d4ae8de52b7dc08d92041237fc"; # v3.9.0 works. v3.10 doesn't seem to appear in path or desktop apps.
    astal = {
      url = "github:aylur/astal";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ags = {
      url = "github:aylur/ags";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # zen-browser.url = "github:MarceColl/zen-browser-flake";
    pia = {
      url = "github:Fuwn/pia.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    copyparty.url = "github:9001/copyparty";
    bun2nix = {
      url = "github:nix-community/bun2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    gws = {
      url = "github:googleworkspace/cli";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    bun-scripts = {
      url = "path:../modules/scripts/bun";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.bun2nix.follows = "bun2nix";
    };
    android-nixpkgs = {
      url = "github:tadfisher/android-nixpkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    code-cursor.url = "github:nixos/nixpkgs/5fd8536a9a5932d4ae8de52b7dc08d92041237fc"; # 2.6.22
  };

  outputs = { self, nixpkgs, pia, copyparty, bun2nix, gws, bun-scripts, android-nixpkgs, ... }@inputs:
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
          copyparty.nixosModules.default
          ../modules/system.nix
          ../modules/user.nix
          ../modules/secrets.nix
          ../modules/password-store.nix
          ../modules/kitty.nix
        ];
      };
      createEnv = { user, home, deviceType, isOnWayland, hasGPU }: {
        inherit user home deviceType isOnWayland hasGPU;
        platform = "linux";
        selectPlatform = config: config.linux or { }; # For platform specific configs. Will always return the linux config.
      };
    in
    {
      nixosConfigurations = {
        akatosh = nixpkgs.lib.nixosSystem {
          specialArgs =
            let
              env = createEnv {
                user = "dano";
                home = "/home/dano";
                deviceType = "desktop";
                isOnWayland = true;
                hasGPU = true;
              };
            in
            { inherit inputs system env pia copyparty bun2nix gws android-nixpkgs; bunScriptsPackage = bun-scripts.packages.${system}.default; };
          modules = [
            commonImports
            { }
            createNixCache
            { }
            ../hosts/akatosh.nix
          ];
        };

        azura = nixpkgs.lib.nixosSystem {
          specialArgs =
            let
              env = createEnv {
                user = "dano";
                home = "/home/dano";
                deviceType = "laptop";
                isOnWayland = true;
                hasGPU = false;
              };
            in
            { inherit inputs system env pia copyparty bun2nix gws android-nixpkgs; bunScriptsPackage = bun-scripts.packages.${system}.default; };
          modules = [
            commonImports
            { }
            createNixCache
            { }
            ../hosts/azura.nix
          ];
        };

        mara = nixpkgs.lib.nixosSystem {
          specialArgs =
            let
              env = createEnv {
                user = "dano";
                home = "/home/dano";
                deviceType = "server";
                isOnWayland = false;
                hasGPU = false;
              };
            in
            { inherit inputs system env pia copyparty bun2nix gws android-nixpkgs; bunScriptsPackage = bun-scripts.packages.${system}.default; };
          modules = [
            commonImports
            { }
            createNixCache
            { }
            ../hosts/mara.nix
          ];
        };
      };
      # packages.x86_64-linux.hello = nixpkgs.legacyPackages.x86_64-linux.hello;
      # packages.x86_64-linux.default = self.packages.x86_64-linux.hello;
    };
}
