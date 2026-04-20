{ env, lib, config, ... }:
let
  cfg = config.my.services.syncthing;
in
{
  options.my.services.syncthing = {
    enable = lib.mkEnableOption "Enable the syncthing service with associated config.";
  };

  config = lib.mkIf cfg.enable (env.selectPlatform {
    linux = {
      # TODO: add a web app desktop entry for syncthing:
      # Syncthing uses port 8384 for its web interface, http://localhost:8384
      networking.firewall.allowedTCPPorts = [ 8384 ];

      services.syncthing = {
        enable = true;
        inherit (env) user;
        systemService = true;
        openDefaultPorts = true;
        overrideDevices = true;
        overrideFolders = false; # Cannot have as true when autoAcceptFolders is true for S22
        dataDir = "${env.home}/sync";
        configDir = "${env.home}/.config/syncthing";
        settings = {
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
    };
    # TODO: add syncthing config for darwin:
    darwin = { };
  });
}
