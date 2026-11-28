{
  description = "Unified Linux and Darwin system flake";

  # Inputs are pinned with tack (.tack/pins.toml, locked in .tack/pins.lock.json), not flake.lock.
  # Map package versions → nixpkgs commits:
  #   https://www.nixhub.io/packages/
  #   https://lazamar.co.uk/nix-versions/
  #   https://history.nix-packages.com/
  # Package search (often shows the nixpkgs revision): https://search.nixos.org/
  inputs = { };

  outputs =
    { self, ... }:
    let
      inputs = import ./.tack { };
      inherit (inputs)
        nixpkgs
        nix-darwin
        home-manager
        pia
        copyparty
        bun2nix
        gws
        android-nixpkgs
        import-tree
        ;
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

      # import-tree ./dir now returns a module lambda directly (was { imports = [ ... ]; }).
      importLinuxModules =
        linuxPkgs.lib.pipe import-tree [
          (i: i.filterNot (linuxPkgs.lib.hasInfix "flake")) # Skip other flake files
          (i: i.filterNot (linuxPkgs.lib.hasInfix ".darwin")) # Skip darwin files/dirs
          (i: i ./modules)
        ];

      importDarwinModules =
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
        # Live installer ISO; host is chosen at install: nixos-install --flake .#HOST
        iso = self.nixosConfigurations.installer.config.system.build.isoImage;
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

        # Shared live installer (not a production host). Build: nix build .#iso
        # self.outPath is the flake source; passing the outputs attrset recurses.
        installer = nixpkgs.lib.nixosSystem {
          specialArgs = {
            dotfiles = self.outPath;
          };
          modules = [ ./hosts/installer.nix ];
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
