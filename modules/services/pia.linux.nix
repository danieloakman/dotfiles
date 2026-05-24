{ config, pia, lib, system, ... }:
let
  cfg = config.my.services.pia;
in
{
  options.my.services.pia.enable = lib.mkEnableOption "Enable the Private Internet Access VPN service";

  imports = [
    pia.nixosModules."${system}".default
  ];

  config = lib.mkIf cfg.enable {
    # Provides `pia` command.
    # Currently doesn't work, see issue: https://github.com/Fuwn/pia.nix/issues/2
    # Ended up just populating networkmanager vpn connections with the script from this repo: https://github.com/ThePowerTool/PIA-NetworkManager-GUI-Support
    services.pia = {
      enable = true;
      authUserPassFile = config.sops.secrets.pia_credentials.path;
    };
  };
}
