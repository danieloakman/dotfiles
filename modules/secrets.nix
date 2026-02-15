{ inputs, env, ... }:
let
  # List of secrets to allow the user to access without sudo.
  # Some of these aren't security concerns if they were exposed, but it's better to just hide them anyway.
  secrets = [
    "password_store_git_url" # Git URL for password store
    "pia_credentials" # Private Internet Access credentials 
    "dano_pwd" # Dano's password
    "cursor_api_key" # Cursor API key
  ];
  group = "secrets";
in
{
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  # Create the secrets group:
  users.groups.${group} = {
    members = [
      "root"
      env.user
    ];
  };

  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = "/var/lib/sops-nix/key.txt";

    secrets = builtins.listToAttrs (map
      (secret: {
        name = secret;
        value = {
          inherit group;
          owner = env.user;
          mode = "0440"; # Readable by group
        };
      })
      secrets);
  };
}
