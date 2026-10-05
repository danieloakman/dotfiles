# AdGuard Home — DNS ad blocking over Tailscale.
#
# Host exposure is always Tailscale-only: DNS (53) and the dashboard port open on
# tailscale0; LAN/public stay closed. The web UI listens on all interfaces but the
# firewall only admits it from the tailnet (Homepage widget still uses loopback).
#
# Mode (`my.services.dns-ad-block.mode`):
#
#   opt-in (default) — Do not push this host as a Tailscale global nameserver.
#     Devices keep router/ISP DNS. Opt in by setting a device's DNS to this
#     host's Tailscale IPv4 (`tailscale ip -4`). Opt out by restoring DHCP DNS.
#
#   tailnet — Push this host as the Tailscale global nameserver and enable
#     Override local DNS (via Tailscale API). Every peer that accepts Tailscale
#     DNS uses AdGuard. Per-device off: uncheck "Use Tailscale DNS" /
#     `tailscale set --accept-dns=false` (also disables MagicDNS on that device).
#     Requires a real `tailscale_api_key` in sops (DNS write scope). The current
#     placeholder key will soft-fail for opt-in and hard-fail for tailnet.
#
# This host (`useLocally`, default true): system DNS is 127.0.0.1 → AdGuard;
# Tailscale accept-dns is off; `*.ts.net` is forwarded to 100.100.100.100.
#
# Switching modes runs `adguard-tailscale-dns.service` on activation (needs
# `tailscale_api_key` in sops). Verify:
#   dig @<mara-tailscale-ip> doubleclick.net   # expect blocked
#   dig @<mara-tailscale-ip> example.com       # expect normal A
#
{ lib, config, pkgs, ... }:
let
  cfg = config.my.services.dns-ad-block;
  ts = lib.getExe config.services.tailscale.package;
  jq = lib.getExe pkgs.jq;
  curl = lib.getExe pkgs.curl;

  syncScript = pkgs.writeShellScript "adguard-tailscale-dns-sync" ''
    set -euo pipefail

    mode=${lib.escapeShellArg cfg.mode}
    tailnet=${lib.escapeShellArg cfg.tailnet}
    api_key_file="''${CREDENTIALS_DIRECTORY}/tailscale_api_key"

    if [[ ! -r "$api_key_file" ]]; then
      echo "adguard-tailscale-dns: missing API key credential" >&2
      exit 1
    fi
    api_key="$(tr -d '\n' < "$api_key_file")"

    # Wait briefly for Tailscale to have an IPv4.
    ip=""
    for _ in $(seq 1 30); do
      ip="$(${ts} ip -4 2>/dev/null || true)"
      if [[ -n "$ip" ]]; then
        break
      fi
      sleep 1
    done
    if [[ -z "$ip" ]]; then
      echo "adguard-tailscale-dns: no Tailscale IPv4 yet" >&2
      exit 1
    fi

    base="https://api.tailscale.com/api/v2/tailnet/''${tailnet}/dns"
    auth=(-u "''${api_key}:")

    # Soft-fail helper: opt-in must not break nixos-rebuild when the API key is
    # missing/placeholder; tailnet mode needs a working key to do its job.
    fail_or_soft() {
      local msg="$1"
      if [[ "$mode" == "tailnet" ]]; then
        echo "adguard-tailscale-dns: ERROR: $msg" >&2
        echo "adguard-tailscale-dns: set a real sops secret tailscale_api_key (DNS write scope), or apply DNS manually in the Tailscale admin console." >&2
        exit 1
      fi
      echo "adguard-tailscale-dns: WARNING: $msg (opt-in continues; apply Tailscale DNS manually if needed)" >&2
      exit 0
    }

    http_body="$(mktemp)"
    trap 'rm -f "$http_body"' EXIT
    http_code="$(${curl} -sS -o "$http_body" -w '%{http_code}' "''${auth[@]}" "$base/configuration" || true)"
    if [[ "$http_code" != "200" ]]; then
      fail_or_soft "GET dns/configuration HTTP $http_code ($(head -c 200 "$http_body"))"
    fi
    cfg_json="$(cat "$http_body")"

    if [[ "$mode" == "tailnet" ]]; then
      body="$(${jq} -c --arg ip "$ip" '
        .nameservers = [{ address: $ip, useWithExitNode: true }]
        | .preferences.overrideLocalDNS = true
        | .preferences.magicDNS = (.preferences.magicDNS // true)
      ' <<<"$cfg_json")"
      echo "adguard-tailscale-dns: mode=tailnet nameserver=$ip override=true"
    else
      body="$(${jq} -c --arg ip "$ip" '
        .nameservers = [
          (.nameservers // [])[]
          | select(.address != $ip)
        ]
        | .preferences.overrideLocalDNS = false
        | .preferences.magicDNS = true
      ' <<<"$cfg_json")"
      echo "adguard-tailscale-dns: mode=opt-in removed=$ip override=false"
    fi

    http_code="$(${curl} -sS -o "$http_body" -w '%{http_code}' "''${auth[@]}" \
      -H 'Content-Type: application/json' \
      -X POST \
      --data-binary "$body" \
      "$base/configuration" || true)"
    if [[ "$http_code" != "200" ]]; then
      fail_or_soft "POST dns/configuration HTTP $http_code ($(head -c 200 "$http_body"))"
    fi

    # Clearing all nameservers can disable MagicDNS; re-assert it for opt-in.
    if [[ "$mode" == "opt-in" ]]; then
      http_code="$(${curl} -sS -o "$http_body" -w '%{http_code}' "''${auth[@]}" \
        -H 'Content-Type: application/json' \
        -X POST \
        --data-binary '{"magicDNS":true}' \
        "$base/preferences" || true)"
      if [[ "$http_code" != "200" ]]; then
        fail_or_soft "POST dns/preferences HTTP $http_code ($(head -c 200 "$http_body"))"
      fi
    fi

    echo "adguard-tailscale-dns: synced"
  '';
in
{
  options.my.services.dns-ad-block = {
    enable = lib.mkEnableOption "Enable the DNS AdBlock service";
    port = lib.mkOption {
      type = lib.types.int;
      default = 2899;
    };
    mode = lib.mkOption {
      type = lib.types.enum [
        "opt-in"
        "tailnet"
      ];
      default = "opt-in";
      description = ''
        How clients discover AdGuard DNS.

        - `opt-in`: leave Tailscale global DNS alone (or clear this host from it);
          set a device's DNS to this host's Tailscale IP to use AdGuard.
        - `tailnet`: set this host as the Tailscale global nameserver and enable
          Override local DNS so every peer that accepts Tailscale DNS uses AdGuard.
      '';
    };
    tailnet = lib.mkOption {
      type = lib.types.str;
      default = "-";
      description = ''
        Tailscale API tailnet id for DNS sync (`-` = default tailnet for the API key).
        Used by `adguard-tailscale-dns.service` when applying `mode`.
      '';
    };
    useLocally = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Point this host's system DNS at local AdGuard (127.0.0.1). Disables Tailscale
        accept-dns so MagicDNS does not overwrite resolv.conf; AdGuard forwards
        `*.ts.net` to the Tailscale stub (100.100.100.100).
      '';
    };
    magicDnsSearch = lib.mkOption {
      type = lib.types.str;
      default = "dinosaur-crocodile.ts.net";
      description = ''
        Search domain kept when `useLocally` is true (short names like `mara` still
        resolve via MagicDNS through AdGuard).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    networking = {
      # Open explicitly on tailscale0 so exposure survives a change to trustedInterfaces.
      firewall.interfaces."tailscale0" = {
        allowedTCPPorts = [
          53
          cfg.port
        ];
        allowedUDPPorts = [ 53 ];
      };

      # Host uses AdGuard; Tailscale must not own resolv.conf.
      nameservers = lib.mkIf cfg.useLocally [ "127.0.0.1" ];
      search = lib.mkIf cfg.useLocally [ cfg.magicDnsSearch ];
      networkmanager.dns = lib.mkIf cfg.useLocally "none";
    };

    services.tailscale.extraSetFlags = lib.mkIf cfg.useLocally [ "--accept-dns=false" ];

    services.adguardhome = {
      enable = true;
      openFirewall = false;
      # Reachable on the tailnet via hostname:port; firewall keeps LAN closed.
      host = "0.0.0.0";
      inherit (cfg) port;
      # Non-null settings are required for nixpkgs to merge host/port into the
      # mutable AdGuardHome.yaml (otherwise bind stays at AdGuard defaults).
      settings = {
        dns = {
          # Keep MagicDNS working when the host no longer accepts Tailscale DNS.
          upstream_dns = [
            "[/ts.net/]100.100.100.100"
            "https://dns10.quad9.net/dns-query"
          ];
          bootstrap_dns = [
            "9.9.9.10"
            "149.112.112.10"
          ];
        };
      };
    };

    # Apply Tailscale admin DNS to match `mode` after AdGuard / Tailscale are up.
    systemd.services.adguard-tailscale-dns = {
      description = "Sync Tailscale DNS settings for AdGuard (${cfg.mode})";
      after = [
        "network-online.target"
        "tailscaled.service"
        "adguardhome.service"
      ];
      wants = [
        "network-online.target"
        "tailscaled.service"
      ];
      requires = [ "adguardhome.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        LoadCredential = "tailscale_api_key:${config.sops.secrets.tailscale_api_key.path}";
        ExecStart = syncScript;
      };
      # Re-run when mode / script changes across rebuilds.
      restartTriggers = [
        cfg.mode
        cfg.tailnet
        syncScript
      ];
    };

    my.services.homepage.services."AdGuard" = {
      description =
        if cfg.mode == "tailnet" then
          "Network-wide ad blocking DNS (Tailscale tailnet-wide)"
        else
          "Network-wide ad blocking DNS (Tailscale opt-in)";
      href = "http://${config.networking.hostName}:${toString cfg.port}";
      group = "Network";
      icon = "adguard-home.png";
      widget = {
        type = "adguard";
        url = "http://127.0.0.1:${toString cfg.port}";
        username = "{{HOMEPAGE_FILE_ADGUARD_USERNAME}}";
        password = "{{HOMEPAGE_FILE_ADGUARD_PASSWORD}}";
        fields = [
          "queries"
          "blocked"
          "filtered"
        ];
      };
    };
  };
}
