{ env, ... }:
let
  # gpg-agent has no "infinite" TTL; 34560000s (400 days) is the effective max we use.
  cacheTtl = if env.deviceType == "server" then 34560000 else 604800;
in
{
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
}
