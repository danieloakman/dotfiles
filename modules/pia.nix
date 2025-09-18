{ config, pia, system, ... }: {
  imports = [
    pia.nixosModules."${system}".default
  ];
  # Provides `pia` command.
  # Currently doesn't work, see issue: https://github.com/Fuwn/pia.nix/issues/2
  # Ended up just populating networkmanager vpn connections with the script from this repo: https://github.com/ThePowerTool/PIA-NetworkManager-GUI-Support
  services.pia = {
    enable = true;
    authUserPassFile = config.sops.secrets.pia_credentials.path;
  };
}
