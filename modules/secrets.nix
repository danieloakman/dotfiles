{ inputs, env, ... }:
let
  # List of secrets to allow the user to access without sudo.
  # Some of these aren't security concerns if they were exposed, but it's better to just hide them anyway.
  secrets = [
    "password_store_git_url" # Git URL for password store
    "pia_credentials" # Private Internet Access credentials 
    "dano_pwd"
    "cursor_api_key"
    "google_client_id"
    "google_client_secret"
    "google_calendar_mcp_oath.json"
  ];
  group = "secrets"; # Group to access the secrets
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
    age.keyFile = "${env.home}/.config/sops/age/keys.txt";

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
