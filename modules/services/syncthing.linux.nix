{ env, lib, config, ... }:
let
  cfg = config.my.services.syncthing;
in
{
  options.my.services.syncthing = {
    enable = lib.mkEnableOption "Enable the syncthing service with associated config.";
  };

  # TODO: add syncthing config for darwin (boethiah still uses brew for now).
  config = lib.mkIf (cfg.enable && env.platform == "linux") {
    # TODO: add a web app desktop entry for syncthing:
    # Syncthing uses port 8384 for its web interface.
    # GUI on all interfaces; only admit it from the tailnet.
    networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 8384 ];

    services.syncthing = {
      enable = true;
      inherit (env) user;
      systemService = true;
      openDefaultPorts = true;
      guiAddress = "0.0.0.0:8384";
      # Plaintext from sops; nixpkgs bcrypt-hashes it into the GUI config.
      guiPasswordFile = config.sops.secrets.dano_pwd.path;
      overrideDevices = true;
      overrideFolders = false; # Cannot have as true when autoAcceptFolders is true for S22
      dataDir = "${env.home}/sync";
      configDir = "${env.home}/.config/syncthing";
      settings = {
        gui = {
          user = config.networking.hostName;
          address = "0.0.0.0:8384";
          # Allow http://mara:8384 (Host != localhost) over the tailnet.
          insecureSkipHostcheck = true;
        };
        options.urAccepted = -1; # Do not allow anonymous diagnostics to be sent
        devices = {
          "S22" = {
            name = "Samsung Galaxy S22";
            id = "UVQTGOE-NWABVGC-GIKEUPN-Y2LWRLU-3IXXPUH-4PTLHSW-OTX3D7U-EDQBIQ2";
            autoAcceptFolders = true;
          };
        };
        folders = {
          "obsidian-vault" = {
            enable = true;
            id = "snqde-mxdrc";
            path = "${env.home}/Documents/obsidian-vault";
            label = "Obsidian Vault";
          };
          "general-sync" = {
            enable = true;
            id = "jvfnw-u7jgi";
            path = "${env.home}/Sync";
            label = "General Sync";
          };
        };
      };
    };

    my.services.homepage.services."Syncthing" = {
      description = "File synchronization";
      href = "http://${config.networking.hostName}:8384";
      group = "Files";
      icon = "syncthing.png";
    };
  };
}
