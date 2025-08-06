{ inputs, config, env, ... }:
{
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  sops =
    let
      # List of secrets to allow the user to access without sudo.
      # Some of these aren't security concerns if they were exposed, but it's better to just hide them anyway.
      secrets = [
        "password_store_git_url" # Git URL for password store
        "doakman_gpg_key" # Public key for GPG signing
      ];
    in
    {
      defaultSopsFile = ../secrets/secrets.yaml;
      defaultSopsFormat = "yaml";
      age.keyFile = "/var/lib/sops-nix/key.txt";

      secrets = builtins.listToAttrs (map (secret: {
        name = secret;
        value = {
          owner = config.users.users.${env.user}.name;
        };
      }) secrets);
    };
}
