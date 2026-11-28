{ env, lib, pkgs, ... }:
let
  # gpg-agent has no "infinite" TTL; 34560000s (400 days) is the effective max we use.
  cacheTtl = if env.deviceType == "server" then 34560000 else 604800;
in
{
  config = env.selectPlatform {
    linux = {
      home-manager.users.${env.user} = {
        services = {
          gpg-agent = {
            enable = true;
            enableZshIntegration = true;
            defaultCacheTtl = cacheTtl;
            maxCacheTtl = cacheTtl;
            # pinentryPackage = pkgs.pinentry;
          };

          # Add gnome-keyring to handle auto gpg password entry, amongst other things:
          gnome-keyring = {
            enable = true;
            components = [ "pkcs11" "secrets" "ssh" ];
          };
        };
      };
    };
    darwin = {
      home-manager.users.${env.user} = {
        home.file.".gnupg/gpg-agent.conf".text = ''
          default-cache-ttl ${toString cacheTtl}
          max-cache-ttl ${toString cacheTtl}
          pinentry-program ${lib.getExe pkgs.pinentry_mac}
        '';
      };
    };
  };
}
