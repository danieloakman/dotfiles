{ ... }: {
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

      # Configure the Tailscale interface to support Wake-on-LAN
      tailscale0 = {
        useDHCP = false;
        # Enable Wake-on-LAN for the Tailscale interface
        wakeOnLan.enable = true;
      };
    };


    # Enable Wake-on-LAN over Tailscale by allowing the magic packet port
    firewall = {
      # Allow the wakeonlan discard port to be used.
      allowedTCPPorts = [ 9 ];
      allowedUDPPorts = [ 9 ];
    };
  };

  services = {
    tailscale = {
      # Enable subnet routes to allow Wake-on-LAN packets to reach this machine
      useRoutingFeatures = "both";
      # Keep Tailscale running during suspend
      extraUpFlags = [ "--accept-dns=false" "--accept-routes=true" ];
    };
  };

  # Configure systemd to handle suspend/resume with Tailscale
  systemd.services = {
    tailscaled = {
      # Ensure Tailscale starts early and stays running
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      # Keep Tailscale running during suspend
      restartTriggers = [ ];

      # Configure service to handle suspend/resume properly
      serviceConfig = {
        # Don't stop the service during suspend
        KillMode = "mixed";
        # Restart on failure
        Restart = "always";
        RestartSec = "5s";
      };
    };

    # Configure systemd-suspend to handle Tailscale properly
    systemd-suspend = {
      # Ensure Tailscale is ready before suspend
      after = [ "tailscaled.service" ];
      wants = [ "tailscaled.service" ];
    };

    # Configure systemd-resume to handle Tailscale properly
    systemd-resume = {
      # Ensure Tailscale is ready after resume
      after = [ "tailscaled.service" ];
      wants = [ "tailscaled.service" ];
    };
  };

  # Power management configuration for Wake-on-LAN
  powerManagement = {
    # Enable Wake-on-LAN support
    enable = true;
  };
}
