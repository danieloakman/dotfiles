{ env, ... }: {
  networking.firewall.allowedTCPPorts = [ 22 ];

  services = {
    tailscale.enable = true;
    # Enable the OpenSSH daemon:
    openssh = {
      enable = true;
      # These commented out settings would force public key authentication, but we don't need that for now as we're using
      # tailscale to allow access to the machine. Without logging in to tailscale, only LAN access is allowed (with a password).
      settings.PasswordAuthentication = false;
      settings.KbdInteractiveAuthentication = false;
    };
  };

  home-manager.users.${env.user}.home = {
    # Create a writable SSH config file instead of using programs.ssh.
    # In particular, when ssh'ing using cursor, it requires a writable ssh config file.
    file.".ssh/config" = {
      text = ''
        # Recommended to edit for actual device in use

        Host github github.comakatosh azura tail9f1d8
        IdentityFile ~/.ssh/djo-personal
        IdentitiesOnly yes
        AddKeysToAgent yes
        Host github github.com stash
        ControlPath ~/.ssh/control-%h-%p-%r
        ControlMaster auto
        ControlPersist yes
        ServerAliveInterval 30
        # Host bitbucket.org
        # IdentityFile ~/.ssh/djo-auxilis
        # IdentitiesOnly yes
        # AddKeysToAgent yes
        # host gitlab gitlab.com
        # IdentityFile ~/.ssh/frogco
        # IdentitiesOnly yes
        # AddKeysToAgent yes
      '';
      # Make the file writable
      onChange = ''
        chmod 600 ~/.ssh/config
      '';
    };

    # Starts the ssh-agent
    # services.ssh-agent.enable = true;
  };
}
