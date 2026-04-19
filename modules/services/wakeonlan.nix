{ lib, config, env, ... }:
let
  cfg = config.my.services.wakeonlan;
in
{
  options.my.services.wakeonlan.enable = lib.mkEnableOption "Enable the wakeonlan service and therefor allowing this machine to be woken up via wired ethernet.";

  config = lib.mkIf cfg.enable (env.selectPlatform {
    linux = {
      # Wake-on-LAN configuration for ethernet interface
      networking = {
        # Allow the wakeonlan discard port to be used.
        interfaces = {
          enp0s31f6 = {
            useDHCP = true;
            # Use `ip link show enp0s31f6` to see the mac address for this interface.
            # Then on another machine, run `wakeonlan <mac address>` to wake this host up from a sleep state.
            wakeOnLan.enable = true;
          };
        };

        firewall = {
          # Allow the wakeonlan discard port to be used.
          allowedTCPPorts = [ 9 ];
          allowedUDPPorts = [ 9 ];
        };
      };
    };
  });

}
