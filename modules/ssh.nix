{ env, ... }: {
  networking.firewall = {
    allowedTCPPorts = [
      22 # SSH
    ];

    # Open the DNS ports in the firewall for tailscale.
    trustedInterfaces = [ "tailscale0" ];
  };

  services = {
    tailscale = {
      enable = true;
      openFirewall = true;
      # Enables the Tailscale Serve configs:
      # For some reason, this doesn't work at the moment. So I'm just going to add enable and disable scripts for each service.
      serve.enable = false;
      extraSetFlags = [
        "--operator=${env.user}"
        "--accept-routes=true"
        "--shields-up=false"
      ];
    };

    # Enable the OpenSSH daemon:
    openssh = {
      enable = true;
      # These commented out settings would force public key authentication, but we don't need that for now as we're using
      # tailscale to allow access to the machine. Without logging in to tailscale, only LAN access is allowed (with a password).
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        # Add timeout settings to prevent hanging connections
        ClientAliveInterval = 60;
        ClientAliveCountMax = 3;
        # Ensure SSH daemon starts after network is ready
        UsePAM = true;
        # Allow connections from Tailscale interface
        ListenAddress = "0.0.0.0";
      };
    };
  };

  home-manager.users.${env.user} = {
    # Starts the tailscale-systray, which is a tray icon for tailscale.
    services.tailscale-systray.enable = true;
  };
}
