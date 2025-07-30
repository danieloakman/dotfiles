{ inputs, config, env, ... }:
{
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  sops =
    let
      # List of secrets to allow the user to access without sudo.
      secrets = [
        "password_store_git_url"
      ];
    in
    {
      defaultSopsFile = ../secrets/secrets.yaml;
      defaultSopsFormat = "yaml";
      # age.keyFile = ../secrets/keys.txt;

      secrets = builtins.listToAttrs (map (secret: {
        name = secret;
        value = {
          owner = config.users.users.${env.user}.name;
        };
      }) secrets);
    };
}
