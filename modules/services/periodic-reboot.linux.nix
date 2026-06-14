# Optional scheduled reboots with inhibitor/unit checks and a retry window.
{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.periodicReboot;

  cronParts = lib.splitString " " cfg.schedule;
  cronMinute = builtins.elemAt cronParts 0;
  cronHour = builtins.elemAt cronParts 1;
  cronDom = builtins.elemAt cronParts 2;
  cronMonth = builtins.elemAt cronParts 3;
  cronDow = builtins.elemAt cronParts 4;

  simpleSchedule = cronDom == "*" && cronMonth == "*";

  systemdDays = [
    "Sun"
    "Mon"
    "Tue"
    "Wed"
    "Thu"
    "Fri"
    "Sat"
  ];

  cronDowToSystemd =
    dow:
    lib.concatStringsSep "," (
      map (
        day:
        let
          idx = parseInt day;
        in
        systemdDays.${if idx == 7 then 0 else idx}
      ) (lib.splitString "," dow)
    );

  parseInt =
    s:
    lib.foldl' (n: c: n * 10 + lib.toInt c) 0 (lib.stringToCharacters s);

  parseClock =
    time:
    let
      parts = lib.splitString ":" time;
    in
    {
      hour = parseInt (builtins.elemAt parts 0);
      minute = parseInt (builtins.elemAt parts 1);
    };

  startTime = parseClock "${cronHour}:${cronMinute}";
  endTime = parseClock cfg.retryUntil;

  toMinutes =
    { hour, minute }:
    hour * 60 + minute;

  startMins = toMinutes startTime;
  endMins = toMinutes endTime;

  retryCount = builtins.div (endMins - startMins) cfg.retryInterval + 1;

  retryTimes = lib.genList (i: startMins + i * cfg.retryInterval) retryCount;

  pad2 =
    n:
    let
      s = toString n;
    in
    if lib.stringLength s < 2 then "0${s}" else s;

  formatClock =
    mins:
    let
      hour = mins / 60;
      minute = lib.mod mins 60;
    in
    "${pad2 hour}:${pad2 minute}:00";

  dayPrefix = if cronDow == "*" then "" else "${cronDowToSystemd cronDow} ";

  calendarEntries = map (mins: "${dayPrefix}*-*-* ${formatClock mins}") retryTimes;

  periodicRebootScript = pkgs.writeShellScript "periodic-reboot" ''
    set -eu

    log() {
      ${pkgs.systemd}/bin/logger -t periodic-reboot "$*"
    }

    ${lib.optionalString cfg.requireNoInhibitors ''
      if ${pkgs.gawk}/bin/awk '
        $6 ~ /(^|:)shutdown(:|$)/ { found = 1 }
        END { exit !found }
      ' <($(${pkgs.systemd}/bin/systemd-inhibit --list --no-legend 2>/dev/null || true)); then
        log "deferred: shutdown inhibitor active"
        exit 0
      fi
    ''}

    ${lib.concatMapStrings (
      unit:
      ''
        if ${pkgs.systemd}/bin/systemctl is-active --quiet ${lib.escapeShellArg unit}; then
          log "deferred: ${unit} is active"
          exit 0
        fi
      ''
    ) cfg.deferWhileActive}

    ${lib.optionalString (cfg.maxLoad != null) ''
      load=$(${pkgs.gawk}/bin/awk '{print $1}' /proc/loadavg)
      maxLoad=${toString cfg.maxLoad}
      if ${pkgs.gawk}/bin/awk -v load="$load" -v max="$maxLoad" 'BEGIN { exit !(load > max) }'; then
        log "deferred: load $load exceeds $maxLoad"
        exit 0
      fi
    ''}

    log "conditions met, rebooting"
    exec ${pkgs.systemd}/bin/systemctl reboot
  '';
in
{
  options.my.services.periodicReboot = {
    enable = lib.mkEnableOption ''
      Periodic reboot via a systemd timer with optional deferral checks.
      Disabled by default.
    '';

    schedule = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Cron time specification (five fields: minute hour day-of-month month day-of-week)
        that defines the start of the reboot window, e.g. `"0 1 * * *"` for daily 01:00.

        Day-of-month and month must be `*`. Day-of-week may be `*` (daily) or a cron
        weekday list/range such as `"0"` or `"1,3,5"`.

        Required when `enable` is true.
      '';
    };

    retryInterval = lib.mkOption {
      type = lib.types.int;
      default = 30;
      description = ''
        Minutes between reboot attempts within the retry window.
      '';
    };

    retryUntil = lib.mkOption {
      type = lib.types.str;
      default = "05:00";
      description = ''
        Stop retrying after this clock time (HH:MM, same day as `schedule`).
      '';
    };

    deferWhileActive = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "postgresql-backup.service"
        "immich-backup.service"
      ];
      description = ''
        Systemd units that defer reboot while active.
      '';
    };

    requireNoInhibitors = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Defer reboot while a shutdown inhibitor lock is held. Critical jobs should wrap
        themselves in `systemd-inhibit --what=shutdown`.
      '';
    };

    maxLoad = lib.mkOption {
      type = lib.types.nullOr lib.types.float;
      default = null;
      example = 4.0;
      description = ''
        Defer reboot when the 1-minute load average exceeds this value. Disabled when null.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.schedule != null && cfg.schedule != "";
        message = "my.services.periodicReboot.schedule must be a non-empty string when my.services.periodicReboot.enable is true.";
      }
      {
        assertion = lib.length cronParts == 5;
        message = "my.services.periodicReboot.schedule must be a five-field cron expression.";
      }
      {
        assertion = simpleSchedule;
        message = "my.services.periodicReboot.schedule day-of-month and month must be '*' (only daily/weekly patterns are supported).";
      }
      {
        assertion = cfg.retryInterval > 0;
        message = "my.services.periodicReboot.retryInterval must be positive.";
      }
      {
        assertion = endMins >= startMins;
        message = "my.services.periodicReboot.retryUntil must be at or after the schedule time on the same day.";
      }
    ];

    systemd.services.periodic-reboot = {
      description = "Conditional periodic reboot";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = periodicRebootScript;
      };
    };

    systemd.timers.periodic-reboot = {
      description = "Periodic reboot retry window";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = lib.concatStringsSep "\n" calendarEntries;
        Persistent = true;
        Unit = "periodic-reboot.service";
      };
    };
  };
}
