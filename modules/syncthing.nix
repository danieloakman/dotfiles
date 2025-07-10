{ env, ... }: {
  # Syncthing uses port 8384 for its web interface, http://localhost:8384
  networking.firewall.allowedTCPPorts = [ 8384 ];

  services.syncthing = {
    enable = true;
    inherit (env) user;
    systemService = true;
    openDefaultPorts = true;
    overrideDevices = true;
    overrideFolders = false; # Cannot have as true when autoAcceptFolders is true for S22
    dataDir = "/home/${env.user}/sync";
    configDir = "/home/${env.user}/.config/syncthing";
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
          path = "/home/${env.user}/Documents/obsidian-vault";
          label = "Obsidian Vault";
        };
        "general-sync" = {
          enable = true;
          id = "jvfnw-u7jgi";
          path = "/home/${env.user}/Sync";
          label = "General Sync";
        };
      };
    };
  };
}
