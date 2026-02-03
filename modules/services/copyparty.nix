{ pkgs, config, env, ... }:
let
  port = 3923;
  user = "copyparty";
  group = "copyparty";
in
{
  users.users.${user}.extraGroups = [
    # Allow the copyparty user to access secrets:
    "secrets"
    # Access to storage devices:
    "storage"
  ];

  services.copyparty = {
    enable = true;
    inherit user group;

    # directly maps to values in the [global] section of the copyparty config.
    # see `copyparty --help` for available options
    settings = {
      i = "0.0.0.0";
      p = port;
    };

    accounts = {
      ${env.user} = {
        passwordFile = config.sops.secrets.dano_pwd.path;
      };
    };

    # groups = {};

    volumes = {
      # Had problems accessing the home directory, so disabled it for now.
      # "/" = {
      #   path = "/home/${env.user}";
      #   access = {
      #     rw = [ env.user ];
      #   };
      # };
      "/" = {
        path = "/run/media/HDD_1";
        access = {
          rw = [ env.user ];
        };
      };
    };
  };

  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "tailscale-svc-copyparty-up" ''
      tailscale serve --service=svc:copyparty --https=443 127.0.0.1:${toString port}
    '')
    (writeShellScriptBin "tailscale-svc-copyparty-down" ''
      tailscale serve clear svc:copyparty
    '')
  ];

  # Start after sops-nix so secrets are available
  systemd.services.copyparty.after = [ "sops-nix.service" ];
}
