{ env, ... }:
{
  home-manager.users.${env.user} = {
    services = {
      gpg-agent = {
        enable = true;
        enableZshIntegration = true;
        defaultCacheTtl = 34560000; # 400 days
        maxCacheTtl = 34560000;
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
