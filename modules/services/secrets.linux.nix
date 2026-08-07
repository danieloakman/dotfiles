{ inputs, env, ... }:
let
  # List of secrets to allow the user to access without sudo.
  # Some of these aren't security concerns if they were exposed, but it's better to just hide them anyway.
  secrets = [
    "password_store_git_url" # Git URL for password store
    "pia_username" # Private Internet Access username
    "pia_password" # Private Internet Access password

    "dano_pwd"
    "cursor_api_key"
    "main_gh_token"
    "postiz_jwt_secret"
    "jellyfin_api_key"
    "immich_api_key"
    "tandoor_secret_key"
    "gcloud_access_token"
    "gcloud_credentials.json"
    "adguard_username"
    "adguard_pwd"
    "paperless_username"
    "paperless_pwd"
  ];
  group = "secrets"; # Group to access the secrets
in
{
  # This can be moved to two separate files for linux and darwin. services/secrets/import.linux.nix and services/secrets/import.darwin.nix.
  # But boethiah was having trouble getting it to work.
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
    defaultSopsFile = ../../secrets/secrets.yaml;
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
