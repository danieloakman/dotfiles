{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.tandoor;
  user = "tandoor_recipes";
in
{
  options.my.services.tandoor = {
    enable = lib.mkEnableOption "Enable Tandoor Recipes, a self-hosted AI food recipe manager.";
    port = lib.mkOption {
      type = lib.types.int;
      default = 19876;
    };
  };

  config = lib.mkIf cfg.enable {
    services.tandoor-recipes = {
      inherit user;
      enable = true;
      address = "127.0.0.1";
      inherit (cfg) port;
      extraConfig = {
        SECRET_KEY_FILE = "${config.sops.secrets.tandoor_secret_key.path}";
        ALLOWED_HOSTS = "127.0.0.1,tandoor.dinosaur-crocodile.ts.net";
      };
    };

    users = {
      groups.${user} = { };
      users.${user} = {
        isSystemUser = true;
        extraGroups = [
          # Allow the tandoor user to access secrets:
          "secrets"
        ];
      };
    };

    environment.systemPackages = with pkgs; [
      (writeShellScriptBin "tailscale-svc-tandoor-up" ''
        tailscale serve --service=svc:tandoor --https=443 127.0.0.1:${toString cfg.port}
      '')
      (writeShellScriptBin "tailscale-svc-tandoor-down" ''
        tailscale serve clear svc:tandoor
      '')
    ];
  };
}
