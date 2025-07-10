{ inputs, config, ... }:
{
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = /home/dano/.config/sops/age/keys.txt;

    secrets.root_password = {
      owner = config.users.users.${config.env.user}.name;
    };
  };
}
