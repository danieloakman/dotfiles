{
  description = "nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager, ... }:
    let
      system = "aarch64-darwin";
      env = {
        user = "daniel.brown";
        home = "/Users/daniel.brown";
        hasGPU = false;
        platform = "darwin";
        selectPlatform = config: config.darwin or { };
      };
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
      };
    in
    {
      darwinConfigurations =
        let
          boethiahConfig = {
            inherit system;
            specialArgs = { inherit inputs system env self pkgs; };
            modules = [
              home-manager.darwinModules.home-manager
              ../hosts/boethiah.nix
            ];
          };
        in
        {
          # TODO: just use one of these host names. For some reason changing the host name on mac isn't always working.
          "boethiah" = nix-darwin.lib.darwinSystem boethiahConfig;
          "MY797HJWD7" = nix-darwin.lib.darwinSystem boethiahConfig;
        };
    };
}
