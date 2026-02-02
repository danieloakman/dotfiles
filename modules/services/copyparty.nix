{ pkgs, config, env, ... }:
let
  copypartyPort = 3923;
  user = "copyparty";
  group = "copyparty";
in
{
  # Allow the copyparty user to access secrets:
  users.users.${user}.extraGroups = [ "secrets" ];

  services.copyparty = {
    enable = true;
    inherit user group;

    # directly maps to values in the [global] section of the copyparty config.
    # see `copyparty --help` for available options
    settings = {
      i = "0.0.0.0";
      p = copypartyPort;
    };

    accounts = {
      ${env.user} = {
        passwordFile = config.sops.secrets.dano_pwd.path;
      };
    };

    # groups = {};

    volumes = {
      "/" = {
        path = "/home/${env.user}";
        access = {
          rw = [ env.user ];
        };
      };
      "HDD_1" = {
        path = "/run/media/HDD_1";
        access = {
          rw = [ env.user ];
        };
      };
    };
  };

  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "tailscale-svc-copyparty-up" ''
      tailscale serve --service=svc:copyparty --https=443 127.0.0.1:${toString copypartyPort}
    '')
    (writeShellScriptBin "tailscale-svc-copyparty-down" ''
      tailscale serve clear svc:copyparty
    '')
  ];
}
