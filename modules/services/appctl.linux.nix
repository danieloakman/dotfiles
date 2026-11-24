# appctl — pause/resume registered non-vital app services + light memory hardening.
#
# Services opt in via `my.services.appctl.services.<name>.units`. The CLI stops/starts
# those systemd units and records desired on/off so a boot oneshot can re-apply lean mode.
#
# Future enhancement: optional per-service `onCommand` / `offCommand` (or similar) to
# override unit stop/start for non-systemd apps (compose, launchd, ad-hoc processes).
{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.appctl;
  active = cfg.enable || cfg.services != { };

  unitBase = unit: lib.removeSuffix ".service" unit;

  servicesJson = pkgs.writeText "appctl-services.json" (
    builtins.toJSON (
      lib.mapAttrs (_name: svc: {
        inherit (svc) description units scope;
        user = svc.user;
      }) cfg.services
    )
  );

  appctl = pkgs.writeShellApplication {
    name = "appctl";
    runtimeInputs = with pkgs; [
      coreutils
      jq
      systemd
    ];
    text = ''
      set -euo pipefail

      REGISTRY=/etc/appctl/services.json
      STATE_DIR=/var/lib/appctl
      DESIRED="$STATE_DIR/desired.json"

      usage() {
        cat <<'EOF'
Usage:
  appctl list
  appctl status [name]
  appctl <name|all> on|off

Control registered non-vital app services (see my.services.appctl.services).
EOF
      }

      need_registry() {
        if [[ ! -r $REGISTRY ]]; then
          echo "appctl: missing $REGISTRY (is my.services.appctl active?)" >&2
          exit 1
        fi
      }

      ensure_state() {
        mkdir -p "$STATE_DIR"
        if [[ ! -f $DESIRED ]]; then
          echo '{}' >"$DESIRED"
        fi
      }

      names() {
        jq -r 'keys[]' "$REGISTRY" | sort
      }

      has_name() {
        jq -e --arg n "$1" 'has($n)' "$REGISTRY" >/dev/null
      }

      # systemctl for a registered service: system or user (--machine=user@).
      sc() {
        local scope="$1" user="$2"
        shift 2
        if [[ $scope == user ]]; then
          if [[ -z $user ]]; then
            echo "appctl: user-scope service missing user" >&2
            exit 1
          fi
          systemctl --user --machine="''${user}@" "$@"
        else
          systemctl "$@"
        fi
      }

      desired_get() {
        local name="$1"
        ensure_state
        jq -r --arg n "$name" '.[$n] // "on"' "$DESIRED"
      }

      desired_set() {
        local name="$1" value="$2"
        ensure_state
        local tmp
        tmp=$(mktemp)
        jq --arg n "$name" --arg v "$value" '.[$n]=$v' "$DESIRED" >"$tmp"
        mv "$tmp" "$DESIRED"
      }

      unit_active_summary() {
        local scope="$1" user="$2"
        shift 2
        local u live=0 total=0
        for u in "$@"; do
          total=$((total + 1))
          if sc "$scope" "$user" is-active --quiet "$u" 2>/dev/null; then
            live=$((live + 1))
          fi
        done
        echo "$live/$total active"
      }

      cmd_list() {
        need_registry
        ensure_state
        local name scope user desc desired summary
        printf '%-16s %-8s %-14s %s\n' "NAME" "DESIRED" "UNITS" "DESCRIPTION"
        while IFS= read -r name; do
          scope=$(jq -r --arg n "$name" '.[$n].scope' "$REGISTRY")
          user=$(jq -r --arg n "$name" '.[$n].user // empty' "$REGISTRY")
          desc=$(jq -r --arg n "$name" '.[$n].description' "$REGISTRY")
          desired=$(desired_get "$name")
          mapfile -t units < <(jq -r --arg n "$name" '.[$n].units[]' "$REGISTRY")
          summary=$(unit_active_summary "$scope" "$user" "''${units[@]}")
          printf '%-16s %-8s %-14s %s\n' "$name" "$desired" "$summary" "$desc"
        done < <(names)
      }

      cmd_status() {
        need_registry
        ensure_state
        local filter="''${1:-}"
        local name scope user desc desired u
        while IFS= read -r name; do
          if [[ -n $filter && $name != "$filter" ]]; then
            continue
          fi
          scope=$(jq -r --arg n "$name" '.[$n].scope' "$REGISTRY")
          user=$(jq -r --arg n "$name" '.[$n].user // empty' "$REGISTRY")
          desc=$(jq -r --arg n "$name" '.[$n].description' "$REGISTRY")
          desired=$(desired_get "$name")
          echo "$name ($desc)"
          echo "  desired: $desired  scope: $scope''${user:+ user=$user}"
          while IFS= read -r u; do
            printf '  %-40s %s\n' "$u" "$(sc "$scope" "$user" is-active "$u" 2>/dev/null || echo inactive)"
          done < <(jq -r --arg n "$name" '.[$n].units[]' "$REGISTRY")
        done < <(names)
        if [[ -n $filter ]] && ! has_name "$filter"; then
          echo "appctl: unknown service '$filter'" >&2
          exit 1
        fi
      }

      set_one() {
        local name="$1" action="$2"
        local scope user u
        scope=$(jq -r --arg n "$name" '.[$n].scope' "$REGISTRY")
        user=$(jq -r --arg n "$name" '.[$n].user // empty' "$REGISTRY")
        mapfile -t units < <(jq -r --arg n "$name" '.[$n].units[]' "$REGISTRY")
        if [[ $action == off ]]; then
          echo "appctl: stopping $name (''${units[*]})"
          sc "$scope" "$user" stop "''${units[@]}" || true
          desired_set "$name" off
        else
          echo "appctl: starting $name (''${units[*]})"
          sc "$scope" "$user" start "''${units[@]}"
          desired_set "$name" on
        fi
      }

      cmd_set() {
        local target="$1" action="$2"
        need_registry
        ensure_state
        if [[ $action != on && $action != off ]]; then
          usage >&2
          exit 1
        fi
        if [[ $target == all ]]; then
          local name
          while IFS= read -r name; do
            set_one "$name" "$action"
          done < <(names)
          return
        fi
        if ! has_name "$target"; then
          echo "appctl: unknown service '$target'" >&2
          exit 1
        fi
        set_one "$target" "$action"
      }

      # Re-apply desired=off after boot (NixOS activation starts WantedBy units again).
      cmd_apply() {
        need_registry
        ensure_state
        local name desired
        while IFS= read -r name; do
          desired=$(desired_get "$name")
          if [[ $desired == off ]]; then
            set_one "$name" off
          fi
        done < <(names)
      }

      case "''${1:-}" in
        ""|-h|--help) usage ;;
        list) cmd_list ;;
        status) shift; cmd_status "''${1:-}" ;;
        apply) cmd_apply ;;
        all)
          if [[ ''${#} -lt 2 ]]; then usage >&2; exit 1; fi
          cmd_set all "$2"
          ;;
        *)
          if [[ ''${#} -lt 2 ]]; then usage >&2; exit 1; fi
          cmd_set "$1" "$2"
          ;;
      esac
    '';
  };

  # Memory/OOM drop-ins only for *.service (not sockets/timers).
  isServiceUnit = unit: lib.hasSuffix ".service" unit;

  unitDropin =
    unit: svc:
    let
      base = unitBase unit;
      mem = lib.optionalAttrs (svc.memoryHigh != null) {
        MemoryHigh = svc.memoryHigh;
      };
      oom = lib.optionalAttrs (svc.oomScoreAdjust != null) {
        OOMScoreAdjust = svc.oomScoreAdjust;
      };
    in
    lib.optionalAttrs (isServiceUnit unit && (mem != { } || oom != { })) {
      ${base}.serviceConfig = mem // oom;
    };

  systemServiceDropins = lib.mkMerge (
    lib.concatLists (
      lib.mapAttrsToList (
        _name: svc:
        lib.optionals (svc.scope == "system") (map (unit: unitDropin unit svc) svc.units)
      ) cfg.services
    )
  );

  userServiceDropins = lib.mkMerge (
    lib.concatLists (
      lib.mapAttrsToList (
        _name: svc:
        lib.optionals (svc.scope == "user") (map (unit: unitDropin unit svc) svc.units)
      ) cfg.services
    )
  );

  vitalDropins = lib.mkMerge (
    map (
      unit:
      let
        base = unitBase unit;
      in
      {
        ${base}.serviceConfig = {
          ManagedOOMPreference = "avoid";
          OOMScoreAdjust = -500;
          MemoryMin = "64M";
        };
      }
    ) cfg.vitalUnits
  );
in
{
  options.my.services.appctl = {
    enable = lib.mkEnableOption ''
      appctl CLI, desired-state apply, and memory/watchdog hardening.
      Also activates automatically when any `services` entry is registered.
    '';

    services = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              description = lib.mkOption {
                type = lib.types.str;
                default = name;
                description = "Human-readable label for `appctl list`.";
              };
              units = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                description = "Systemd unit names (usually `*.service`) stopped/started together.";
              };
              scope = lib.mkOption {
                type = lib.types.enum [
                  "system"
                  "user"
                ];
                default = "system";
                description = "systemctl vs systemctl --user --machine=USER@";
              };
              user = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Login user for scope=user (required when scope is user).";
              };
              memoryHigh = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                example = "2G";
                description = "Optional MemoryHigh applied to each listed unit.";
              };
              oomScoreAdjust = lib.mkOption {
                type = lib.types.nullOr lib.types.int;
                default = 300;
                description = "OOMScoreAdjust for listed units (higher = prefer kill under pressure).";
              };
            };
          }
        )
      );
      default = { };
      description = "Logical app services that appctl can turn on/off.";
    };

    vitalUnits = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "tailscaled.service"
        "NetworkManager.service"
        "sshd.service"
      ];
      description = "System units protected from oomd preference (never registered in services).";
    };

    runtimeWatchdog = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "30s";
      description = ''
        systemd RuntimeWatchdogSec (hardware watchdog pet interval). Set null to leave unset.
      '';
    };
  };

  config = lib.mkIf active {
    assertions = lib.mapAttrsToList (name: svc: {
      assertion = svc.scope != "user" || svc.user != null;
      message = "my.services.appctl.services.${name}: scope=user requires user to be set.";
    }) cfg.services
    ++ lib.mapAttrsToList (name: svc: {
      assertion = svc.units != [ ];
      message = "my.services.appctl.services.${name}: units must be non-empty.";
    }) cfg.services;

    environment.systemPackages = [ appctl ];
    environment.etc."appctl/services.json".source = servicesJson;

    systemd.services = lib.mkMerge [
      systemServiceDropins
      vitalDropins
      {
        appctl-apply = {
          description = "Apply appctl desired=off state after boot";
          after = [ "multi-user.target" ];
          wants = [ "multi-user.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${lib.getExe appctl} apply";
            StateDirectory = "appctl";
          };
        };
      }
    ];

    systemd.user.services = userServiceDropins;

    # Prefer killing pressured cgroups in system/user slices (Fedora-like).
    systemd.oomd = {
      enableSystemSlice = true;
      enableUserSlices = true;
    };

    systemd.settings.Manager = lib.mkIf (cfg.runtimeWatchdog != null) {
      RuntimeWatchdogSec = cfg.runtimeWatchdog;
    };
  };
}
