{
  description = "Unified Linux and Darwin system flake";

  # Map package versions → nixpkgs commits:
  #   https://www.nixhub.io/packages/
  #   https://lazamar.co.uk/nix-versions/
  #   https://history.nix-packages.com/
  # Package search (often shows the nixpkgs revision): https://search.nixos.org/
  inputs = {
    # nixpkgsStable.url = "github:nixos/nixpkgs/nixos-23.11";
    # Weekly nixpkgs snapshots via FlakeHub (Determinate Systems).
    # https://docs.determinate.systems/guides/advanced-installation/#nixos
    nixpkgs.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-weekly/0.1";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    import-tree.url = "github:vic/import-tree";
    wrapper-modules.url = "github:BirdeeHub/nix-wrapper-modules"; # https://birdeehub.github.io/nix-wrapper-modules
    # Noctalia v5 (native rewrite). No nixpkgs.follows so the Cachix binary cache stays usable.
    # https://docs.noctalia.dev/v5/getting-started/nixos/
    noctalia.url = "github:noctalia-dev/noctalia";
    # https://docs.noctalia.dev/v5/greeter/
    noctalia-greeter = {
      url = "github:noctalia-dev/noctalia-greeter";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # devenv.url = "github:cachix/devenv";
    openvpn24.url = "github:nixos/nixpkgs/2d38b664b4400335086a713a0036aafaa002c003";
    # Shared systems list without x86_64-darwin (Nixpkgs 26.05 deprecation warning).
    # future-26.11 drops Intel macOS; replaces the old local bun2nix-systems flake.
    systems.url = "github:nix-systems/default/future-26.11";
    flake-utils = {
      url = "github:numtide/flake-utils/11707dc2f618dd54ca8739b309ec4fc024de578b";
      inputs.systems.follows = "systems";
    };
    stylix = {
      url = "github:danth/stylix";
      inputs.systems.follows = "systems";
    };
    # Still needed by modules/gnome.linux/guake.nix; drop with unused-shells cleanup (#34).
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
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
    copyparty.url = "github:9001/copyparty";
    # No nixpkgs.follows so nix-community.cachix.org can serve prebuilt
    # cache-entry-creator (Zig) instead of compiling it against our nixpkgs.
    bun2nix = {
      url = "github:nix-community/bun2nix";
      inputs.systems.follows = "systems";
    };
    gws = {
      url = "github:googleworkspace/cli";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
    android-nixpkgs = {
      url = "github:tadfisher/android-nixpkgs";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
    llama-cpp.url = "github:nixos/nixpkgs/80d901ec0377e19ac3f7bb8c035201e2e098cc97"; # Version 8069 (d5dfc33)
    stirling-pdf.url = "github:nixos/nixpkgs/80d901ec0377e19ac3f7bb8c035201e2e098cc97"; # v1.5.0, v2 changed a lot and broke a lot. Try it again in the future.
    lazyvim = {
      url = "github:pfassina/lazyvim-nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
    agent-sandbox = {
      url = "github:archie-judd/agent-sandbox.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hunk = {
      url = "github:modem-dev/hunk";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        bun2nix.follows = "bun2nix";
      };
    };
  };

  outputs =
    { self
    , nixpkgs
    , nix-darwin
    , home-manager
    , pia
    , copyparty
    , bun2nix
    , gws
    , android-nixpkgs
    , import-tree
    , stirling-pdf
    , ...
    }@inputs:
    let
      createNixCache = _: {
        nix = {
          registry = {
            nixpkgs.flake = nixpkgs;
          };
          settings = {
            substituters = [
              "https://nix-community.cachix.org"
              "https://srid.cachix.org"
              "https://noctalia.cachix.org" # Prebuilt noctalia (v5), avoids compiling from source
            ];
            trusted-public-keys = [
              "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
              "srid.cachix.org-1:MTQ6ksbfz3LBMmjyPh0PLmos+1x+CdtJxA/J2W+PQxI="
              "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
            ];
          };
        };
      };

      createEnv =
        { platform
        , user
        , home
        , deviceType
        , isOnWayland ? false
        , hasGPU ? false
        ,
        }:
        {
          inherit
            user
            home
            deviceType
            isOnWayland
            hasGPU
            platform
            ;
          selectPlatform =
            cfg:
            let
              selected = cfg.${platform} or null;
            in
            if builtins.isAttrs selected then
              nixpkgs.lib.mkMerge [
                selected
                (cfg.any or { })
              ]
            else if builtins.isList selected then
              selected ++ (cfg.any or [ ])
            else if builtins.isString selected then
              selected + (cfg.any or "")
            else if builtins.isInt selected then
              selected + (cfg.any or 0)
            else if builtins.isFloat selected then
              selected + (cfg.any or 0.0)
            else if builtins.isBool selected then
              # `||` means any=true forces true even when the platform arm is false.
              # Prefer omitting `any` for bools, or use attrs + mkMerge if you need overrides.
              selected || (cfg.any or false)
            else
              cfg.any or { };
        };

      linuxSystem = "x86_64-linux";
      darwinSystem = "aarch64-darwin";

      nixpkgsFor = system: import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      linuxPkgs = nixpkgsFor linuxSystem;
      darwinPkgs = nixpkgsFor darwinSystem;

      importLinuxModules =
        _:
        linuxPkgs.lib.pipe import-tree [
          (i: i.filterNot (linuxPkgs.lib.hasInfix "flake")) # Skip other flake files
          (i: i.filterNot (linuxPkgs.lib.hasInfix ".darwin")) # Skip darwin files/dirs
          (i: i ./modules)
        ];

      importDarwinModules =
        _:
        darwinPkgs.lib.pipe import-tree [
          (i: i.filterNot (darwinPkgs.lib.hasInfix "flake")) # Skip other flake files
          (i: i.filterNot (darwinPkgs.lib.hasInfix ".linux")) # Skip .linux files/dirs
          (i: i ./modules)
        ];

      forAllSystems = fn: nixpkgs.lib.genAttrs [ linuxSystem darwinSystem ] (
        system: fn (nixpkgsFor system)
      );

      # Hosts after shared modules so plain host assignments override profile enables.
      mkNixosHost =
        { name
        , deviceType
        , isOnWayland ? false
        , hasGPU ? false
        ,
        }:
        nixpkgs.lib.nixosSystem {
          specialArgs = {
            system = linuxSystem;
            inherit
              inputs
              pia
              copyparty
              bun2nix
              gws
              android-nixpkgs
              import-tree
              ;
            env = createEnv {
              platform = "linux";
              user = "dano";
              home = "/home/dano";
              inherit deviceType isOnWayland hasGPU;
            };
            stirlingPdfPackage = stirling-pdf.legacyPackages.${linuxSystem}.stirling-pdf;
          };
          modules = [
            inputs.home-manager.nixosModules.home-manager
            createNixCache
            importLinuxModules
            ./hosts/${name}.nix
          ];
        };
    in
    {
      packages = forAllSystems (pkgs: {
        opencode-cursor-proxy = pkgs.callPackage ./modules/programs/opencode/cursor-proxy/_package.nix { };
      } // nixpkgs.lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == linuxSystem) {
        bun-scripts = pkgs.callPackage ./modules/programs/bun-scripts.linux/_package.nix {
          inherit bun2nix;
        };
      });

      checks = {
        ${linuxSystem} = {
          opencode-cursor-proxy = self.packages.${linuxSystem}.opencode-cursor-proxy;
          bun-scripts = self.packages.${linuxSystem}.bun-scripts;
        };
        ${darwinSystem} = {
          opencode-cursor-proxy = self.packages.${darwinSystem}.opencode-cursor-proxy;
        };
      };

      nixosConfigurations = {
        akatosh = mkNixosHost {
          name = "akatosh";
          deviceType = "desktop";
          isOnWayland = true;
          hasGPU = true;
        };

        azura = mkNixosHost {
          name = "azura";
          deviceType = "laptop";
          isOnWayland = true;
        };

        mara = mkNixosHost {
          name = "mara";
          deviceType = "server";
        };
      };

      darwinConfigurations =
        let
          boethiahConfig = {
            system = darwinSystem;
            specialArgs = {
              system = darwinSystem;
              inherit inputs self darwinPkgs gws;
              env = createEnv {
                platform = "darwin";
                user = "daniel.brown";
                home = "/Users/daniel.brown";
                deviceType = "desktop";
                hasGPU = false;
              };
              pkgs = darwinPkgs;
            };
            modules = [
              home-manager.darwinModules.home-manager
              importDarwinModules
              ./hosts/boethiah.nix
            ];
          };
        in
        {
          # Boethiah's hostname couldn't be changed fully for some reason. So just defining both hostnames here, original and renamed one:
          boethiah = nix-darwin.lib.darwinSystem boethiahConfig;
          MY797HJWD7 = nix-darwin.lib.darwinSystem boethiahConfig;
        };
    };
}
