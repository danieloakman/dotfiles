{ pkgs, config, env, lib, inputs, ... }:
let
  cfg = config.my.services.copyparty;
  user = "copyparty";
  group = "copyparty";
in
{
  imports = [
    inputs.copyparty.nixosModules.default
  ];

  options.my.services.copyparty = {
    enable = lib.mkEnableOption "Enable the Copyparty service";
    port = lib.mkOption {
      type = lib.types.int;
      default = 3923;
    };
    root-path = lib.mkOption {
      type = lib.types.str;
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = cfg.root-path != null;
      message = "copyparty.root-path must be set";
    }];

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
        i = "127.0.0.1";
        p = cfg.port;
      };

      accounts = {
        ${env.user} = {
          inherit (cfg) passwordFile;
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
          path = cfg.root-path;
          access = {
            rw = [ env.user ];
          };
        };
      };
    };

    environment.systemPackages = with pkgs; [
      (writeShellScriptBin "tailscale-svc-copyparty-up" ''
        tailscale serve --service=svc:copyparty --https=443 127.0.0.1:${toString cfg.port}
      '')
      (writeShellScriptBin "tailscale-svc-copyparty-down" ''
        tailscale serve clear svc:copyparty
      '')
    ];

    # Start after sops-nix so secrets are available
    systemd.services.copyparty.after = [ "sops-nix.service" ];

    my.services.homepage.services."Copyparty" = {
      description = "File System UI";
      # href = "http://${config.networking.hostName}:${toString cfg.port}";
      href = "https://copyparty.dinosaur-crocodile.ts.net";
    };
  };
}
