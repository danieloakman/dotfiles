{ config, pia, system, ... }: {
  imports = [
    pia.nixosModules."${system}".default
  ];
  # Provides `pia` command.
  # Currently doesn't work, see issue: https://github.com/Fuwn/pia.nix/issues/2
  services.pia = {
    enable = true;
    authUserPassFile = config.sops.secrets.pia_credentials.path;
  };
}
