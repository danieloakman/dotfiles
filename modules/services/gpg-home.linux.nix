{ env, ... }:
{
  home-manager.users.${env.user} = {
    services = {
      gpg-agent = {
        enable = true;
        enableZshIntegration = true;
        defaultCacheTtl = 604800; # 1 week
        maxCacheTtl = 604800;
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
