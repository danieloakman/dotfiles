{ ... }: {
  networking.firewall.allowedTCPPorts = [ 22 ];

  services = {
    tailscale.enable = true;
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

  # Ensure SSH starts after network and Tailscale are ready
  systemd.services.openssh = {
    after = [ "network-online.target" "tailscaled.service" ];
    wants = [ "network-online.target" "tailscaled.service" ];
  };

  # home-manager.users.${env.user} = {
  #   # Starts the ssh-agent
  #   services.ssh-agent.enable = true;
  # };
}
