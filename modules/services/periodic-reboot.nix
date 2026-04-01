# Optional scheduled reboots via cron (five-field schedule).
{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.periodicReboot;
in
{
  options.my.services.periodicReboot = {
    enable = lib.mkEnableOption ''
      Periodic reboot via `services.cron` with a classic five-field schedule.
      Disabled by default.
    '';

    schedule = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Cron time specification (five fields: minute hour day-of-month month day-of-week),
        e.g. `"0 4 * * 0"` for weekly Sunday 04:00.

        Required when `enable` is true.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.schedule != null && cfg.schedule != "";
        message = "my.services.periodicReboot.schedule must be a non-empty string when my.services.periodicReboot.enable is true.";
      }
    ];

    services.cron = {
      enable = true;
      systemCronJobs = [
        "${cfg.schedule} root ${pkgs.systemd}/bin/systemctl reboot"
      ];
    };
  };
}
