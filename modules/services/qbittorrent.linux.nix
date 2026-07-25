{ pkgs, lib, config, ... }:
let
  cfg = config.my.services.qbittorrent;
  inherit (cfg) port torrentingPort downloadDir;
  portStr = toString port;
  incompleteDir = "${downloadDir}/incomplete";
  piaCa = ./pia.linux/pia-ca.rsa.4096.crt;
  authPath = "/run/secrets/pia-openvpn-auth";
  profileDir = "/var/lib/qBittorrent";

  # Stable IDs so host bind-mounts (downloads + profile) match the container user.
  qbittorrentUid = 981;
  qbittorrentGid = 976;
  hostStateVersion = config.system.stateVersion;
in
{
  options.my.services.qbittorrent = {
    enable = lib.mkEnableOption "Enable the qBittorrent-nox service";
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "WebUI port (loopback/host-veth only; expose via Tailscale serve).";
    };
    torrentingPort = lib.mkOption {
      type = lib.types.port;
      default = 6881;
      description = "BitTorrent peer port (only relevant without VPN; with VPN, peers use the tunnel).";
    };
    downloadDir = lib.mkOption {
      type = lib.types.str;
      description = "Directory where torrents are downloaded.";
    };
    vpn = {
      enable = lib.mkEnableOption ''
        Run qBittorrent inside a private NixOS container whose only WAN path is
        a PIA OpenVPN tunnel (kill-switched: qBittorrent binds to the OpenVPN unit).
      '';
      remote = lib.mkOption {
        type = lib.types.str;
        default = "au-sydney.privacy.network";
        description = "PIA OpenVPN remote hostname.";
      };
      remotePort = lib.mkOption {
        type = lib.types.port;
        default = 1197;
        description = "PIA OpenVPN remote port.";
      };
      proto = lib.mkOption {
        type = lib.types.enum [ "udp" "tcp" ];
        default = "udp";
        description = "OpenVPN transport protocol.";
      };
      hostAddress = lib.mkOption {
        type = lib.types.str;
        default = "10.233.2.1";
        description = "IPv4 address of the host side of the container veth.";
      };
      localAddress = lib.mkOption {
        type = lib.types.str;
        default = "10.233.2.2";
        description = "IPv4 address of the container side of the veth (WebUI target).";
      };
      externalInterface = lib.mkOption {
        type = lib.types.str;
        description = ''
          Host uplink interface used for NAT so the container can reach PIA
          before the tunnel is up (e.g. `eno1`).
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [
        {
          assertion = cfg.downloadDir != "";
          message = "my.services.qbittorrent.downloadDir must be set";
        }
        {
          assertion = !cfg.vpn.enable || cfg.vpn.externalInterface != "";
          message = "my.services.qbittorrent.vpn.externalInterface must be set when vpn.enable is true";
        }
      ];

      users.groups.qbittorrent.gid = qbittorrentGid;
      users.users.qbittorrent = {
        isSystemUser = true;
        group = "qbittorrent";
        uid = qbittorrentUid;
        extraGroups = [ "storage" ];
      };

      systemd.tmpfiles.rules = [
        "d ${downloadDir} 0750 qbittorrent qbittorrent -"
        "d ${incompleteDir} 0750 qbittorrent qbittorrent -"
        "d ${profileDir} 0750 qbittorrent qbittorrent -"
      ];

      my.services.homepage.services."qBittorrent" = {
        description = "BitTorrent download manager";
        href = "https://qbittorrent.dinosaur-crocodile.ts.net";
      };
    }

    # Host service (no VPN confinement).
    (lib.mkIf (!cfg.vpn.enable) {
      services.qbittorrent = {
        enable = true;
        webuiPort = port;
        inherit torrentingPort;
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
    })

    # Private network container + PIA OpenVPN kill switch.
    (lib.mkIf cfg.vpn.enable {
      sops.templates."pia-openvpn-auth" = {
        content = ''
          ${config.sops.placeholder.pia_username}
          ${config.sops.placeholder.pia_password}
        '';
      };

      networking.nat = {
        enable = true;
        internalInterfaces = [ "ve-qbittorrent" ];
        externalInterface = cfg.vpn.externalInterface;
      };

      # NetworkManager must not reclaim the container veth.
      networking.networkmanager.unmanaged = [ "interface-name:ve-*" ];

      networking.firewall.trustedInterfaces = [ "ve-qbittorrent" ];

      environment.systemPackages = with pkgs; [
        (writeShellScriptBin "tailscale-svc-qbittorrent-up" ''
          tailscale serve --service=svc:qbittorrent --https=443 http://${cfg.vpn.localAddress}:${portStr}
        '')
        (writeShellScriptBin "tailscale-svc-qbittorrent-down" ''
          tailscale serve clear svc:qbittorrent
        '')
      ];

      systemd.services."container@qbittorrent" = {
        after = [
          "sops-nix.service"
          "network-online.target"
        ];
        wants = [ "network-online.target" ];
      };

      containers.qbittorrent = {
        autoStart = true;
        privateNetwork = true;
        enableTun = true;
        hostAddress = cfg.vpn.hostAddress;
        localAddress = cfg.vpn.localAddress;

        bindMounts = {
          ${downloadDir} = {
            hostPath = downloadDir;
            isReadOnly = false;
          };
          ${profileDir} = {
            hostPath = profileDir;
            isReadOnly = false;
          };
          ${authPath} = {
            hostPath = config.sops.templates."pia-openvpn-auth".path;
            isReadOnly = true;
          };
        };

        config =
          { lib, ... }:
          {
            system.stateVersion = hostStateVersion;

            users.groups.qbittorrent.gid = qbittorrentGid;
            users.users.qbittorrent = {
              isSystemUser = true;
              group = "qbittorrent";
              uid = qbittorrentUid;
            };

            environment.etc."openvpn/pia-ca.rsa.4096.crt".source = piaCa;

            networking = {
              useHostResolvConf = lib.mkForce false;
              useDHCP = false;
              defaultGateway = cfg.vpn.hostAddress;
              # Bootstrap DNS so OpenVPN can resolve the PIA remote before the tunnel is up.
              nameservers = [
                "1.1.1.1"
                "9.9.9.9"
              ];
              firewall = {
                enable = true;
                # Private veth only reaches the host; still pin WebUI explicitly.
                allowedTCPPorts = [ port ];
              };
            };

            services.resolved.enable = true;

            services.openvpn.servers.pia = {
              autoStart = true;
              updateResolvConf = true;
              authUserPass = authPath;
              config = ''
                client
                dev tun
                proto ${cfg.vpn.proto}
                remote ${cfg.vpn.remote} ${toString cfg.vpn.remotePort}
                resolv-retry infinite
                nobind
                persist-key
                persist-tun
                cipher AES-256-CBC
                auth SHA256
                tls-client
                remote-cert-tls server
                verb 1
                reneg-sec 0
                # Same MTU fix as the NetworkManager PIA profiles.
                mssfix
                ca /etc/openvpn/pia-ca.rsa.4096.crt
              '';
            };

            services.qbittorrent = {
              enable = true;
              webuiPort = port;
              inherit torrentingPort;
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
                  # Reachable via host veth only (container firewall).
                  Address = "0.0.0.0";
                  # Tailscale serve connects from the host veth, not loopback,
                  # so LocalHostAuth no longer covers the WebUI.
                  LocalHostAuth = false;
                  AuthSubnetWhitelistEnabled = true;
                  AuthSubnetWhitelist = "${cfg.vpn.hostAddress}/32";
                };
              };
              extraArgs = [ "--confirm-legal-notice" ];
            };

            # Kill switch: qBittorrent only runs while the PIA tunnel unit is up.
            systemd.services.qbittorrent = {
              after = [ "openvpn-pia.service" ];
              requires = [ "openvpn-pia.service" ];
              bindsTo = [ "openvpn-pia.service" ];
            };
          };
      };
    })
  ]);
}
