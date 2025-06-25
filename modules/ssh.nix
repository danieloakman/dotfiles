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

  home-manager.users.${env.user} = {
    programs.ssh = {
      enable = true;
      addKeysToAgent = "yes";
      controlMaster = "auto";
      controlPath = "~/.ssh/control-%h-%p-%r";
      controlPersist = "yes";
      matchBlocks = {
        "github github.com akatosh azura tail9f1d8" = {
          identityFile = "~/.ssh/djo-personal";
          identitiesOnly = true;
        };
        "github github.com stash" = {
          serverAliveInterval = 30;
        };
        # "bitbucket.org" = {
        #   identityFile = "~/.ssh/djo-auxilis";
        #   identitiesOnly = true;
        # };
        # "gitlab gitlab.com" = {
        #   identityFile = "~/.ssh/frogco";
        #   identitiesOnly = true;
        # };
      };
    };

    # Starts the ssh-agent
    # services.ssh-agent.enable = true;
  };
}
