# Host CLIs for switching the qBittorrent container's PIA OpenVPN remote
# and probing/searching apibay through the tunnel.
{
  pkgs,
  lib,
  profilesBySlug,
  vpnRemotePath,
  defaultProfile,
  containerName ? "qbittorrent",
}:
let
  profilesJson = builtins.toJSON (
    lib.mapAttrs (_slug: p: {
      inherit (p) host port proto id name;
    }) profilesBySlug
  );
  profilesFile = pkgs.writeText "qbittorrent-vpn-profiles.json" profilesJson;

  # Curated exits likelier to reach indexers; --all uses the full catalog.
  defaultTestOrder = [
    "de-germany-so"
    "nl-netherlands-so"
    "nl-amsterdam"
    "czech"
    "sweden"
    "swiss"
    "france"
    "uk-london"
    "uk-manchester"
    "ca-ontario-so"
    "us-streaming"
    "us-streaming-2"
    "us-newyorkcity"
    "sg"
    "japan"
  ];

  testOrderFile = pkgs.writeText "qbittorrent-vpn-test-order.txt" (
    lib.concatMapStrings (s: s + "\n") (
      lib.filter (s: profilesBySlug ? ${s}) defaultTestOrder
    )
  );

  commonPreamble = ''
    PROFILES_FILE=${profilesFile}
    VPN_REMOTE_CONF=${lib.escapeShellArg vpnRemotePath}
    CONTAINER=${lib.escapeShellArg containerName}
    DEFAULT_PROFILE=${lib.escapeShellArg defaultProfile}
    CURL=${lib.getExe pkgs.curl}
    JQ=${lib.getExe pkgs.jq}
    NIXOS_CONTAINER=/run/current-system/sw/bin/nixos-container

    need_root() {
      if [[ "$(id -u)" -ne 0 ]]; then
        echo "error: run as root (e.g. sudo $(basename "$0") ...)" >&2
        exit 1
      fi
    }

    container_run() {
      "$NIXOS_CONTAINER" run "$CONTAINER" -- "$@"
    }

    profile_field() {
      local slug=$1 field=$2
      "$JQ" -r --arg s "$slug" --arg f "$field" '.[$s][$f] // empty' "$PROFILES_FILE"
    }

    require_profile() {
      local slug=$1
      if ! "$JQ" -e --arg s "$slug" 'has($s)' "$PROFILES_FILE" >/dev/null; then
        echo "error: unknown profile '$slug' (try qbittorrent-vpn-list)" >&2
        exit 1
      fi
    }

    current_profile() {
      if [[ -f "$VPN_REMOTE_CONF" ]]; then
        local from_comment
        from_comment=$(sed -n 's/^# qbittorrent-vpn profile=//p' "$VPN_REMOTE_CONF" | head -n1)
        if [[ -n "$from_comment" ]]; then
          printf '%s\n' "$from_comment"
          return 0
        fi
      fi
      printf '%s\n' "$DEFAULT_PROFILE"
    }

    write_remote_conf() {
      local slug=$1
      local host port proto
      require_profile "$slug"
      host=$(profile_field "$slug" host)
      port=$(profile_field "$slug" port)
      proto=$(profile_field "$slug" proto)
      mkdir -p "$(dirname "$VPN_REMOTE_CONF")"
      umask 022
      {
        echo "# qbittorrent-vpn profile=$slug"
        echo "proto $proto"
        echo "remote $host $port"
      } >"$VPN_REMOTE_CONF"
    }

    wait_tunnel() {
      local attempts=0
      while (( attempts < 45 )); do
        if container_run systemctl is-active --quiet openvpn-pia.service; then
          # Give tun a moment after ActiveState=active.
          sleep 2
          return 0
        fi
        sleep 1
        attempts=$((attempts + 1))
      done
      echo "error: openvpn-pia did not become active" >&2
      return 1
    }

    restart_tunnel() {
      container_run systemctl restart openvpn-pia.service
      wait_tunnel
    }

    # Exit 0 if apibay returns a JSON array (including empty).
    probe_apibay() {
      local body
      if ! body=$(container_run "$CURL" -fsS --max-time 12 \
        'https://apibay.org/q.php?q=ubuntu' 2>/dev/null); then
        return 1
      fi
      printf '%s' "$body" | "$JQ" -e 'type == "array"' >/dev/null 2>&1
    }
  '';

  mkTool =
    name: text:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [
        pkgs.coreutils
        pkgs.gnused
        pkgs.gnugrep
        pkgs.gawk
        pkgs.jq
        pkgs.curl
      ];
      # jq programs intentionally use single quotes so bash does not expand $vars.
      excludeShellChecks = [ "SC2016" ];
      text = commonPreamble + text;
    };

  listTool = mkTool "qbittorrent-vpn-list" ''
    "$JQ" -r 'to_entries | sort_by(.key)[] | "\(.key)\t\(.value.id)\t\(.value.host)"' "$PROFILES_FILE"
  '';

  statusTool = mkTool "qbittorrent-vpn-status" ''
    slug=$(current_profile)
    echo "profile: $slug"
    if [[ -f "$VPN_REMOTE_CONF" ]]; then
      echo "config:  $VPN_REMOTE_CONF"
      grep -E '^(proto|remote) ' "$VPN_REMOTE_CONF" | sed 's/^/  /' || true
    else
      echo "config:  (missing — will be seeded on next openvpn start)"
    fi
    if [[ "$(id -u)" -eq 0 ]] && "$NIXOS_CONTAINER" status "$CONTAINER" >/dev/null 2>&1; then
      echo -n "tunnel:  "
      container_run systemctl is-active openvpn-pia.service 2>/dev/null || echo "unknown"
      echo -n "apibay:  "
      if probe_apibay; then
        echo "ok"
      else
        echo "unreachable"
      fi
      echo -n "exit ip: "
      container_run "$CURL" -fsS --max-time 8 https://ifconfig.me/ip 2>/dev/null || echo "unknown"
    else
      echo "(run as root for tunnel/apibay checks)"
    fi
  '';
  switchTool = mkTool "qbittorrent-vpn-switch" ''
    if [[ $# -ne 1 ]]; then
      echo "usage: qbittorrent-vpn-switch <profile-slug>" >&2
      echo "see:   qbittorrent-vpn-list" >&2
      exit 1
    fi
    need_root
    slug=$1
    require_profile "$slug"
    echo "switching qBittorrent VPN to $slug..."
    write_remote_conf "$slug"
    restart_tunnel
    echo "active profile: $slug"
  '';

  testTool = mkTool "qbittorrent-vpn-test" ''
    need_root

    use_all=0
    query_slugs=()
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --all)
          use_all=1
          shift
          ;;
        -h|--help)
          echo "usage: qbittorrent-vpn-test [--all] [profile-slug...]"
          echo "  Probes apibay.org through the qBittorrent PIA tunnel."
          echo "  Switches endpoints until one works, then leaves that profile active."
          echo "  Default profile order: curated shortlist (see --all for every PIA endpoint)."
          exit 0
          ;;
        *)
          query_slugs+=("$1")
          shift
          ;;
      esac
    done

    slugs=()
    if [[ ''${#query_slugs[@]} -gt 0 ]]; then
      slugs=("''${query_slugs[@]}")
    elif [[ "$use_all" -eq 1 ]]; then
      mapfile -t slugs < <("$JQ" -r 'keys[]' "$PROFILES_FILE" | sort)
    else
      mapfile -t slugs < ${testOrderFile}
      # Always try the current profile first.
      cur=$(current_profile)
      slugs=("''${cur}" "''${slugs[@]}")
      # Dedup while preserving order.
      mapfile -t slugs < <(printf '%s\n' "''${slugs[@]}" | awk 'NF && !seen[$0]++')
    fi

    original=$(current_profile)
    echo "probing apibay via PIA (starting from $original)..."

    for slug in "''${slugs[@]}"; do
      if ! "$JQ" -e --arg s "$slug" 'has($s)' "$PROFILES_FILE" >/dev/null; then
        echo "skip unknown profile: $slug" >&2
        continue
      fi
      echo -n "try $slug ... "
      write_remote_conf "$slug"
      if ! restart_tunnel; then
        echo "tunnel failed"
        continue
      fi
      if probe_apibay; then
        echo "ok"
        echo "using profile: $slug"
        exit 0
      fi
      echo "blocked/unreachable"
    done

    echo "error: no working profile found; restoring $original" >&2
    write_remote_conf "$original"
    restart_tunnel || true
    exit 1
  '';

  searchTool = mkTool "qbittorrent-search-tpb" ''
    if [[ $# -lt 1 ]]; then
      echo "usage: qbittorrent-search-tpb <query...>" >&2
      exit 1
    fi
    need_root
    # apibay is case-sensitive; match the nova3 plugin lowercase quirk.
    raw="$*"
    # bash tolower
    query=$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')
    enc=$(printf '%s' "$query" | "$JQ" -sRr @uri)
    body=$(container_run "$CURL" -fsS --max-time 20 \
      "https://apibay.org/q.php?q=''${enc}")
    if ! printf '%s' "$body" | "$JQ" -e 'type == "array"' >/dev/null; then
      echo "error: apibay did not return JSON (VPN blocked? try qbittorrent-vpn-test)" >&2
      exit 1
    fi
    count=$(printf '%s' "$body" | "$JQ" 'length')
    if [[ "$count" -eq 0 ]]; then
      echo "no results for: $query"
      exit 0
    fi
    printf '%s' "$body" | "$JQ" -r '
      sort_by(-(.seeders|tonumber? // 0))[:40][] |
      "\(.seeders // 0)s \(.leechers // 0)l\t\(.name)\tmagnet:?xt=urn:btih:\(.info_hash)"
    '
  '';
in
pkgs.symlinkJoin {
  name = "qbittorrent-vpn-tools";
  paths = [
    listTool
    statusTool
    switchTool
    testTool
    searchTool
  ];
  meta = {
    description = "qBittorrent PIA VPN switch / apibay search helpers";
  };
}
