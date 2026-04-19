# Comma + prebuilt nix-index database via home-manager (Linux and Darwin).
# See https://github.com/nix-community/comma and https://github.com/nix-community/nix-index-database
{ env, inputs, lib, config, ... }:
let
  cfg = config.my.programs.comma;
in
{
  options.my.programs.comma.enable = lib.mkEnableOption "comma: run nixpkgs commands ad-hoc (e.g. `, cowsay hi`)";

  config = lib.mkIf cfg.enable {
    home-manager.users.${env.user} = {
      imports = [ inputs.nix-index-database.homeModules.default ];
      programs.nix-index-database.comma.enable = true;
    };
  };
}
