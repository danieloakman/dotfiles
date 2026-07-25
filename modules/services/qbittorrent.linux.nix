{ pkgs, lib, config, ... }:
let
  cfg = config.my.services.qbittorrent;
  inherit (cfg) port torrentingPort downloadDir;
  portStr = toString port;
  incompleteDir = "${downloadDir}/incomplete";
in
{
  options.my.services.qbittorrent = {
    enable = lib.mkEnableOption "Enable the qBittorrent-nox service";
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "WebUI port (loopback only; expose via Tailscale serve).";
    };
    torrentingPort = lib.mkOption {
      type = lib.types.port;
      default = 6881;
      description = "BitTorrent peer port (opened in the firewall; not via Tailscale).";
    };
    downloadDir = lib.mkOption {
      type = lib.types.str;
      description = "Directory where torrents are downloaded.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = cfg.downloadDir != "";
      message = "my.services.qbittorrent.downloadDir must be set";
    }];

    users.users.qbittorrent.extraGroups = [ "storage" ];

    systemd.tmpfiles.rules = [
      "d ${downloadDir} 0750 qbittorrent qbittorrent -"
      "d ${incompleteDir} 0750 qbittorrent qbittorrent -"
    ];

    services.qbittorrent = {
      enable = true;
      webuiPort = port;
      inherit torrentingPort;
      # WebUI via Tailscale serve only; peer ports opened separately below.
      openFirewall = false;
      serverConfig = {
        LegalNotice.Accepted = true;
        BitTorrent.Session = {
          DefaultSavePath = downloadDir;
          TempPath = incompleteDir;
          TempPathEnabled = true;
          Port = torrentingPort;
        };
        Preferences.WebUI = {
          Address = "127.0.0.1";
          # Tailscale serve proxies from localhost; skip password for loopback.
          LocalHostAuth = false;
        };
      };
      extraArgs = [ "--confirm-legal-notice" ];
    };

    networking.firewall = {
      allowedTCPPorts = [ torrentingPort ];
      allowedUDPPorts = [ torrentingPort ];
    };

    environment.systemPackages = with pkgs; [
      (writeShellScriptBin "tailscale-svc-qbittorrent-up" ''
        tailscale serve --service=svc:qbittorrent --https=443 http://127.0.0.1:${portStr}
      '')
      (writeShellScriptBin "tailscale-svc-qbittorrent-down" ''
        tailscale serve clear svc:qbittorrent
      '')
    ];

    my.services.homepage.services."qBittorrent" = {
      description = "BitTorrent download manager";
      href = "https://qbittorrent.dinosaur-crocodile.ts.net";
    };
  };
}
