{ pkgs, lib, config, ... }:
let
  cfg = config.my.services.qbittorrent;
  inherit (cfg) port torrenting-port download-dir;
  portStr = toString port;
  incompleteDir = "${download-dir}/incomplete";
  piaCa = ./pia.linux/pia-ca.rsa.4096.crt;
  authPath = "/run/secrets/pia-openvpn-auth";
  profileDir = "/var/lib/qBittorrent";
  enginesDir = "${profileDir}/qBittorrent/data/nova3/engines";
  python3 = "${pkgs.python3}/bin/python3";

  # Official nova3 Pirate Bay plugin (searches apibay.org).
  # apibay is case-sensitive ("Game of Thrones" → empty; "game of thrones" → hits),
  # so lowercase the query before requesting.
  piratebayPlugin =
    pkgs.runCommand "piratebay.py"
      {
        src = pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/qbittorrent/search-plugins/62f296ed47010ab0ea9dbd43257a1a20025d1d1a/nova3/engines/piratebay.py";
          hash = "sha256-hnlIXWchrs27Z/+VxUXG6fZlG7vJg5IS8Zz6LQzjAJc=";
        };
      }
      ''
        ${pkgs.gnused}/bin/sed 's/what = unquote(what)/what = unquote(what).lower()/' "$src" > "$out"
        ${pkgs.gnugrep}/bin/grep -q 'unquote(what).lower()' "$out"
      '';

  # Run as root (`+`) so we can fix ownership if tmpfiles created parents as root.
  installSearchPlugins = pkgs.writeShellScript "qbittorrent-install-search-plugins" ''
    set -euo pipefail
    ${pkgs.coreutils}/bin/mkdir -p "${enginesDir}"
    ${pkgs.coreutils}/bin/chown -R qbittorrent:qbittorrent "${profileDir}/qBittorrent/data/nova3"
    ${pkgs.coreutils}/bin/install -o qbittorrent -g qbittorrent -m644 ${piratebayPlugin} \
      "${enginesDir}/piratebay.py"
  '';

  # Python search plugins need writable+executable memory pages + an explicit interpreter
  # (systemd hardening can leave auto-detect failing even when qbittorrent-nox wraps PATH).
  qbittorrentSearchServiceConfig = {
    MemoryDenyWriteExecute = lib.mkForce false;
    ExecStartPre = [ "+${installSearchPlugins}" ];
    Environment = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "NIX_SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    ];
  };

  qbittorrentSearchPrefs = {
    # Point nova3 at nixpkgs python instead of relying on PATH detection.
    pythonExecutablePath = python3;
  };

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
    torrenting-port = lib.mkOption {
      type = lib.types.port;
      default = 6881;
      description = "BitTorrent peer port (only relevant without VPN; with VPN, peers use the tunnel).";
    };
    download-dir = lib.mkOption {
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
        # DE Streaming Optimized — AU Sydney was blackholing apibay/TPB search.
        default = "de-germany-so.privacy.network";
        description = "PIA OpenVPN remote hostname.";
      };
      remote-port = lib.mkOption {
        type = lib.types.port;
        default = 1197;
        description = "PIA OpenVPN remote port.";
      };
      proto = lib.mkOption {
        type = lib.types.enum [ "udp" "tcp" ];
        default = "udp";
        description = "OpenVPN transport protocol.";
      };
      host-address = lib.mkOption {
        type = lib.types.str;
        default = "10.233.2.1";
        description = "IPv4 address of the host side of the container veth.";
      };
      local-address = lib.mkOption {
        type = lib.types.str;
        default = "10.233.2.2";
        description = "IPv4 address of the container side of the veth (WebUI target).";
      };
      external-interface = lib.mkOption {
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
          assertion = cfg.download-dir != "";
          message = "my.services.qbittorrent.download-dir must be set";
        }
        {
          assertion = !cfg.vpn.enable || cfg.vpn.external-interface != "";
          message = "my.services.qbittorrent.vpn.external-interface must be set when vpn.enable is true";
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
        "d ${download-dir} 0750 qbittorrent qbittorrent -"
        "d ${incompleteDir} 0750 qbittorrent qbittorrent -"
        "d ${profileDir} 0750 qbittorrent qbittorrent -"
        # Create each level explicitly — tmpfiles parent dirs can end up root-owned.
        "d ${profileDir}/qBittorrent/data 0755 qbittorrent qbittorrent -"
        "d ${profileDir}/qBittorrent/data/nova3 0755 qbittorrent qbittorrent -"
        "d ${enginesDir} 0755 qbittorrent qbittorrent -"
      ];

      my.services.homepage.services."qBittorrent" = {
        description = "BitTorrent download manager";
        href = "https://qbittorrent.dinosaur-crocodile.ts.net";
      };

      services.tailscale.serve.services.qbittorrent = {
        endpoints."tcp:443" =
          if cfg.vpn.enable then
            "http://${cfg.vpn.local-address}:${portStr}"
          else
            "http://127.0.0.1:${portStr}";
      };
    }

    # Host service (no VPN confinement).
    (lib.mkIf (!cfg.vpn.enable) {
      services.qbittorrent = {
        enable = true;
        webuiPort = port;
        torrentingPort = torrenting-port;
        openFirewall = false;
        serverConfig = {
          LegalNotice.Accepted = true;
          BitTorrent.Session = {
            DefaultSavePath = download-dir;
            TempPath = incompleteDir;
            TempPathEnabled = true;
            Port = torrenting-port;
          };
          Preferences = {
            WebUI = {
              Address = "127.0.0.1";
              LocalHostAuth = false;
            };
            Search = qbittorrentSearchPrefs;
          };
        };
        extraArgs = [ "--confirm-legal-notice" ];
      };

      systemd.services.qbittorrent.serviceConfig = qbittorrentSearchServiceConfig;

      networking.firewall = {
        allowedTCPPorts = [ torrenting-port ];
        allowedUDPPorts = [ torrenting-port ];
      };
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
        externalInterface = cfg.vpn.external-interface;
      };

      # NetworkManager must not reclaim the container veth.
      networking.networkmanager.unmanaged = [ "interface-name:ve-*" ];

      networking.firewall.trustedInterfaces = [ "ve-qbittorrent" ];

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
        hostAddress = cfg.vpn.host-address;
        localAddress = cfg.vpn.local-address;

        bindMounts = {
          ${download-dir} = {
            hostPath = download-dir;
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
              defaultGateway = cfg.vpn.host-address;
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
              # Keep container nameservers (1.1.1.1 through the tunnel). PIA DNS can sink indexers.
              updateResolvConf = false;
              authUserPass = authPath;
              config = ''
                client
                dev tun
                proto ${cfg.vpn.proto}
                remote ${cfg.vpn.remote} ${toString cfg.vpn.remote-port}
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
                # Ignore PIA-pushed DNS so indexers remain resolvable via 1.1.1.1.
                pull-filter ignore "dhcp-option DNS"
                pull-filter ignore "dhcp-option DNS6"
              '';
            };

            services.qbittorrent = {
              enable = true;
              webuiPort = port;
              torrentingPort = torrenting-port;
              openFirewall = false;
              serverConfig = {
                LegalNotice.Accepted = true;
                BitTorrent.Session = {
                  DefaultSavePath = download-dir;
                  TempPath = incompleteDir;
                  TempPathEnabled = true;
                  Port = torrenting-port;
                };
                Preferences = {
                  WebUI = {
                    # Reachable via host veth only (container firewall).
                    Address = "0.0.0.0";
                    # Tailscale serve connects from the host veth, not loopback,
                    # so LocalHostAuth no longer covers the WebUI.
                    LocalHostAuth = false;
                    AuthSubnetWhitelistEnabled = true;
                    AuthSubnetWhitelist = "${cfg.vpn.host-address}/32";
                  };
                  Search = qbittorrentSearchPrefs;
                };
              };
              extraArgs = [ "--confirm-legal-notice" ];
            };

            # Kill switch: qBittorrent only runs while the PIA tunnel unit is up.
            # Also install the Pirate Bay search plugin (Python needs MDWE off).
            systemd.services.qbittorrent = {
              after = [ "openvpn-pia.service" ];
              requires = [ "openvpn-pia.service" ];
              bindsTo = [ "openvpn-pia.service" ];
              serviceConfig = qbittorrentSearchServiceConfig;
            };
          };
      };
    })
  ]);
}
