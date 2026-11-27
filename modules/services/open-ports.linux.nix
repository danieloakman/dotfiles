# Open common local-dev server ports (Expo/Metro, Vite, etc.).
# Enabled by `my.profiles.dev-workstation` via mkDefault; Linux-only (Darwin
# has no NixOS firewall).
#
# Exposure is limited to:
#   1. tailscale0 (interface-scoped allow lists)
#   2. packets whose IPv4 source is in trustedSubnets (source-based, not
#      interface-based — laptop Wi-Fi may also join public networks)
{ config, lib, ... }:
let
  cfg = config.my.services.open-ports;

  tcpPorts = [
    4173 # Vite preview
    4200 # Angular
    5555 # Android adb wireless
    6006 # Storybook
    8888 # Jupyter
    9222 # Chrome DevTools / Hermes CDP
  ];

  tcpRanges = [
    { from = 3000; to = 3010; } # Node / Next / Convex
    { from = 5000; to = 5005; } # Flask and similar
    { from = 5173; to = 5180; } # Vite
    { from = 8000; to = 8010; } # Generic HTTP
    { from = 8080; to = 8090; } # Generic + Metro 8081
    { from = 9000; to = 9002; } # Generic app servers
    { from = 19000; to = 19006; } # Expo
  ];

  # Expo Go LAN discovery can use UDP in the same range as the TCP ports.
  udpRanges = [
    { from = 19000; to = 19006; }
  ];

  portOrRangeToNft =
    ports: ranges:
    lib.concatStringsSep ", " (
      map toString ports ++ map (r: "${toString r.from}-${toString r.to}") ranges
    );

  nftTcpSet = portOrRangeToNft tcpPorts tcpRanges;
  nftUdpSet = portOrRangeToNft [ ] udpRanges;

  # iptables: one rule per port/range per subnet (multiport caps out at 15).
  iptablesRule =
    action: subnet: proto: portSpec:
    "iptables -${action} nixos-fw -s ${subnet} -p ${proto} --dport ${portSpec} -j nixos-fw-accept";

  iptablesSpecsForSubnet =
    action: subnet:
    lib.concatStringsSep "\n" (
      map (p: iptablesRule action subnet "tcp" (toString p)) tcpPorts
      ++ map (r: iptablesRule action subnet "tcp" "${toString r.from}:${toString r.to}") tcpRanges
      ++ map (r: iptablesRule action subnet "udp" "${toString r.from}:${toString r.to}") udpRanges
    );

  lanIptablesStart = lib.concatMapStringsSep "\n" (iptablesSpecsForSubnet "A") cfg.trustedSubnets;
  lanIptablesStop = lib.concatMapStringsSep "\n" (
    subnet: lib.concatMapStringsSep "\n" (line: "${line} || true") (
      lib.splitString "\n" (iptablesSpecsForSubnet "D" subnet)
    )
  ) cfg.trustedSubnets;

  lanNftRules = lib.concatMapStrings (subnet: ''
    ip saddr ${subnet} tcp dport { ${nftTcpSet} } accept comment "my.services.open-ports trusted subnet"
    ip saddr ${subnet} udp dport { ${nftUdpSet} } accept comment "my.services.open-ports trusted subnet"
  '') cfg.trustedSubnets;
in
{
  options.my.services.open-ports = {
    enable = lib.mkEnableOption ''
      Open common development-server TCP (and a few UDP) ports for local tooling.

      Ports are not opened on all interfaces: only on `tailscale0`, and from
      IPv4 sources in `trustedSubnets` (home LAN by subnet, not interface).
    '';

    trustedSubnets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      # Repo/host configs do not document the home LAN; common residential default.
      default = [ "192.168.1.0/24" ];
      example = [ "192.168.68.0/22" ];
      description = ''
        IPv4 CIDR sources allowed to reach the dev ports on non-Tailscale
        interfaces. Matched by packet source address (nftables `extraInputRules`
        / iptables `extraCommands`), not by ingress interface — so a laptop on
        public Wi-Fi does not expose these ports to that network.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall = {
      # (1) Tailscale: interface-scoped. Also covered while tailscale0 is in
      # trustedInterfaces; listed explicitly so the hole survives removing that.
      interfaces."tailscale0" = {
        allowedTCPPorts = tcpPorts;
        allowedTCPPortRanges = tcpRanges;
        allowedUDPPortRanges = udpRanges;
      };

      # (2) Home LAN by source subnet. nftables path (when backend = nftables).
      extraInputRules = lib.mkIf (cfg.trustedSubnets != [ ]) lanNftRules;

      # (2) Home LAN by source subnet. iptables path (current default backend).
      extraCommands = lib.mkIf (cfg.trustedSubnets != [ ]) lanIptablesStart;
      extraStopCommands = lib.mkIf (cfg.trustedSubnets != [ ]) lanIptablesStop;
    };
  };
}
