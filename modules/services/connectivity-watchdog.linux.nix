# Connectivity watchdog: check internet + Tailscale, soft-remediate with backoff,
# reboot up to N times, then stay powered and keep soft-fixing.
{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.connectivity-watchdog;

  # Convert systemd time spans like "15min" / "2h" to seconds for the shell uptime gate.
  # Supports a single unit suffix: s, min/m, h. Used only for boot-grace.
  bootGraceSec =
    let
      s = cfg.boot-grace;
      match = builtins.match "([0-9]+)(s|min|m|h)?" s;
    in
    if match == null then
      throw "my.services.connectivity-watchdog.boot-grace must look like \"15min\", \"2h\", or \"900\"."
    else
      let
        n = lib.toInt (builtins.elemAt match 0);
        unit = builtins.elemAt match 1;
      in
      if unit == null || unit == "s" then
        n
      else if unit == "min" || unit == "m" then
        n * 60
      else
        n * 3600;

  stateDir = "/var/lib/connectivity-watchdog";
  rebootCountFile = "${stateDir}/reboot-count";

  watchdogScript = pkgs.writeShellScript "connectivity-watchdog" ''
    set -eu

    log() {
      ${pkgs.util-linux}/bin/logger -t connectivity-watchdog "$*"
    }

    internet_ok() {
      if ${pkgs.iputils}/bin/ping -c 3 -W 3 ${lib.escapeShellArg cfg.internet-target} >/dev/null 2>&1; then
        return 0
      fi
      # Fallback when ICMP is blocked but HTTP works.
      if ${pkgs.curl}/bin/curl -sf --max-time 5 -o /dev/null https://connectivitycheck.gstatic.com/generate_204; then
        return 0
      fi
      return 1
    }

    tailscale_ok() {
      status=$(${pkgs.tailscale}/bin/tailscale status --json 2>/dev/null) || return 1
      echo "$status" | ${pkgs.jq}/bin/jq -e '
        .BackendState == "Running"
        and (
          (.Self.Online == true)
          or ((.Self.TailscaleIPs // []) | length > 0)
          or ((.TailscaleIPs // []) | length > 0)
        )
      ' >/dev/null 2>&1
    }

    healthy() {
      internet_ok && tailscale_ok
    }

    read_reboot_count() {
      if [ -f ${lib.escapeShellArg rebootCountFile} ]; then
        ${pkgs.coreutils}/bin/cat ${lib.escapeShellArg rebootCountFile}
      else
        echo 0
      fi
    }

    write_reboot_count() {
      ${pkgs.coreutils}/bin/mkdir -p ${lib.escapeShellArg stateDir}
      echo "$1" > ${lib.escapeShellArg rebootCountFile}
    }

    reset_reboot_count() {
      ${pkgs.coreutils}/bin/rm -f ${lib.escapeShellArg rebootCountFile}
    }

    soft_remediate() {
      if ! internet_ok; then
        log "internet down; restarting NetworkManager"
        ${pkgs.systemd}/bin/systemctl restart NetworkManager.service || true
        return
      fi
      if ! tailscale_ok; then
        log "tailscale unhealthy; restarting tailscaled"
        ${pkgs.systemd}/bin/systemctl restart tailscaled.service || true
        return
      fi
    }

    # Boot grace: skip entirely while the system is still settling.
    uptime_sec=$(${pkgs.gawk}/bin/awk '{print int($1)}' /proc/uptime)
    if [ "$uptime_sec" -lt ${toString bootGraceSec} ]; then
      log "skipped: within boot grace (uptime ''${uptime_sec}s < ${toString bootGraceSec}s)"
      exit 0
    fi

    if healthy; then
      count=$(read_reboot_count)
      if [ "$count" != "0" ]; then
        log "healthy again; clearing reboot counter (was $count)"
        reset_reboot_count
      else
        log "healthy"
      fi
      exit 0
    fi

    log "unhealthy; starting soft remediation (up to ${toString cfg.soft-attempts} attempts)"
    backoff=${toString cfg.initial-backoff-sec}
    attempt=1
    while [ "$attempt" -le ${toString cfg.soft-attempts} ]; do
      soft_remediate
      log "waiting ''${backoff}s after soft attempt $attempt"
      ${pkgs.coreutils}/bin/sleep "$backoff"
      if healthy; then
        count=$(read_reboot_count)
        if [ "$count" != "0" ]; then
          log "recovered after soft attempt $attempt; clearing reboot counter (was $count)"
          reset_reboot_count
        else
          log "recovered after soft attempt $attempt"
        fi
        exit 0
      fi
      backoff=$((backoff * 2))
      attempt=$((attempt + 1))
    done

    count=$(read_reboot_count)
    # Coerce non-numeric / empty to 0.
    case "$count" in
      ""|*[!0-9]*) count=0 ;;
    esac

    if [ "$count" -lt ${toString cfg.max-reboots} ]; then
      next=$((count + 1))
      write_reboot_count "$next"
      log "soft remediation failed; rebooting (attempt $next/${toString cfg.max-reboots})"
      exec ${pkgs.systemd}/bin/systemctl reboot
    fi

    log "soft remediation failed; reboot limit ${toString cfg.max-reboots} reached — staying powered, soft-only mode"
    soft_remediate
    exit 0
  '';
in
{
  options.my.services.connectivity-watchdog = {
    enable = lib.mkEnableOption ''
      Connectivity watchdog: periodic internet + Tailscale checks with soft
      remediation, limited reboot escalation, then stay-powered soft-only mode.
      Disabled by default.
    '';

    check-interval = lib.mkOption {
      type = lib.types.str;
      default = "2h";
      description = ''
        How often to run after the previous run finishes (`OnUnitActiveSec`).
        Systemd time span, e.g. `"2h"`, `"30min"`.
      '';
    };

    boot-grace = lib.mkOption {
      type = lib.types.str;
      default = "15min";
      description = ''
        Delay after boot before the first check (`OnBootSec`), and minimum uptime
        before reboot escalation is allowed. Supports a simple span like
        `"15min"`, `"2h"`, or seconds as `"900"`.
      '';
    };

    max-reboots = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 3;
      description = ''
        Maximum consecutive reboot escalations while unhealthy. After this many
        reboots without recovery, keep soft-remediating but do not reboot or shut down.
        Cleared when health recovers.
      '';
    };

    internet-target = lib.mkOption {
      type = lib.types.str;
      default = "1.1.1.1";
      description = "ICMP ping target used as the primary internet reachability check.";
    };

    soft-attempts = lib.mkOption {
      type = lib.types.ints.positive;
      default = 3;
      description = "Soft remediate → wait → recheck cycles per timer run before reboot escalation.";
    };

    initial-backoff-sec = lib.mkOption {
      type = lib.types.ints.positive;
      default = 60;
      description = "Seconds to wait after the first soft remediation; doubles each attempt.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.tailscale.enable or false;
        message = "my.services.connectivity-watchdog.enable requires services.tailscale.enable.";
      }
      {
        assertion = cfg.max-reboots >= 1;
        message = "my.services.connectivity-watchdog.max-reboots must be at least 1.";
      }
    ];

    systemd.services.connectivity-watchdog = {
      description = "Connectivity watchdog (internet + Tailscale)";
      after = [
        "network-online.target"
        "NetworkManager.service"
        "tailscaled.service"
      ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = watchdogScript;
        StateDirectory = "connectivity-watchdog";
      };
    };

    systemd.timers.connectivity-watchdog = {
      description = "Connectivity watchdog timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = cfg.boot-grace;
        OnUnitActiveSec = cfg.check-interval;
        # Avoid catch-up storms after boot or nixos-rebuild switch.
        Persistent = false;
        Unit = "connectivity-watchdog.service";
      };
    };
  };
}
