# TODO: remove once tailscale module and associated ssh usage through tailscale is stable, as this module would no longer be needed once that's the case.
{ config, env, lib, ... }:
let
  cfg = config.my.services.ssh;
in
{
  options.my.services.ssh = {
    enable = lib.mkEnableOption "Enable the SSH daemon";
  };

  config = lib.mkIf cfg.enable (env.selectPlatform {
    linux = {
      networking.firewall.allowedTCPPorts = [ 22 ];


      services = {
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
            # Restrict sshd to local loopback; remote access should use Tailscale SSH.
            ListenAddress = "127.0.0.1";
          };
        };
      };
    };
  });
}
