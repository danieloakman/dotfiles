# Power management configuration, including CPU frequency scaling, power profiles, etc
{ env, lib, pkgs, config, ... }:
let
  cfg = config.my.services.power-management;

  tlpOnBattery = {
    CPU_BOOST_ON_BAT = if cfg.cpu-boost-on-bat then 1 else 0;
    CPU_HWP_DYN_BOOST_ON_BAT = if cfg.cpu-boost-on-bat then 1 else 0;
    CPU_SCALING_GOVERNOR_ON_BAT = cfg.cpu-scaling-governor-on-bat;
    CPU_ENERGY_PERF_POLICY_ON_BAT = cfg.cpu-energy-perf-policy-on-bat;
    CPU_MIN_PERF_ON_BAT = 0;
    CPU_MAX_PERF_ON_BAT = cfg.cpu-max-perf-on-bat;
    PLATFORM_PROFILE_ON_BAT = cfg.platform-profile-on-bat;
    PCIE_ASPM_ON_BAT = cfg.pcie-aspm-on-bat;
    RUNTIME_PM_ON_BAT = "auto";
    WIFI_PWR_ON_BAT = "on";
    SOUND_POWER_SAVE_ON_BAT = 1;
    START_CHARGE_THRESH_BAT0 = cfg.start-charge-thresh-bat0;
    STOP_CHARGE_THRESH_BAT0 = cfg.stop-charge-thresh-bat0;
  };
in
{
  options.my.services.power-management = {
    thermald.enable = lib.mkOption {
      type = lib.types.bool;
      default = env.deviceType == "laptop";
      description = ''
        Run thermald with Intel DPTF adaptive tables (--adaptive).
        Custom configFile disables --adaptive; only add one after dumping
        /sys/class/thermal on the host.
      '';
    };

    cpu-max-perf-on-bat = lib.mkOption {
      type = lib.types.ints.between 0 100;
      default = 70;
      description = ''
        TLP CPU_MAX_PERF_ON_BAT: cap turbo-ish P-states on battery (0–100).
        Lower saves power; higher feels snappier.
      '';
    };

    cpu-boost-on-bat = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "TLP CPU_BOOST_ON_BAT / CPU_HWP_DYN_BOOST_ON_BAT on battery.";
    };

    cpu-scaling-governor-on-bat = lib.mkOption {
      type = lib.types.enum [
        "performance"
        "powersave"
        "schedutil"
        "ondemand"
        "conservative"
      ];
      default = "powersave";
      description = "TLP CPU_SCALING_GOVERNOR_ON_BAT.";
    };

    cpu-energy-perf-policy-on-bat = lib.mkOption {
      type = lib.types.enum [
        "default"
        "performance"
        "balance_performance"
        "balance_power"
        "power"
      ];
      default = "power";
      description = "TLP CPU_ENERGY_PERF_POLICY_ON_BAT (Intel HWP energy policy).";
    };

    platform-profile-on-bat = lib.mkOption {
      type = lib.types.enum [
        "default"
        "low-power"
        "balanced"
        "performance"
      ];
      default = "low-power";
      description = "TLP PLATFORM_PROFILE_ON_BAT (kernel platform_profile).";
    };

    pcie-aspm-on-bat = lib.mkOption {
      type = lib.types.enum [
        "default"
        "performance"
        "powersave"
        "powersupersave"
      ];
      default = "powersupersave";
      description = "TLP PCIE_ASPM_ON_BAT.";
    };

    start-charge-thresh-bat0 = lib.mkOption {
      type = lib.types.ints.between 0 100;
      default = 60;
      description = "TLP START_CHARGE_THRESH_BAT0: begin charging below this %.";
    };

    stop-charge-thresh-bat0 = lib.mkOption {
      type = lib.types.ints.between 0 100;
      default = 85;
      description = "TLP STOP_CHARGE_THRESH_BAT0: stop charging at this %.";
    };
  };

  config = {
    services = {
      # Better scheduling for CPU cycles:
      system76-scheduler.settings.cfsProfiles.enable = true;

      thermald.enable = cfg.thermald.enable;

      # Disable GNOMEs power management for laptops
      power-profiles-daemon.enable = env.deviceType != "laptop";

      # Enable TLP for laptops
      tlp = {
        enable = env.deviceType == "laptop";
        settings = {
          CPU_BOOST_ON_AC = 1;
          CPU_SCALING_GOVERNOR_ON_AC = "performance";
          CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
          CPU_MIN_PERF_ON_AC = 0;
          CPU_MAX_PERF_ON_AC = 100;
          PLATFORM_PROFILE_ON_AC = "performance";
          PCIE_ASPM_ON_AC = "default";
          RUNTIME_PM_ON_AC = "on";
          WIFI_PWR_ON_AC = "off";
          USB_AUTOSUSPEND = 1;
          NMI_WATCHDOG = 0;
        } // tlpOnBattery;
      };
    };

    environment.systemPackages = with pkgs; [ powertop ];

    powerManagement = {
      enable = true;
      # Enable powertop to see power usage
      powertop.enable = env.deviceType == "laptop";

      # Server-specific power management options
      # For servers, use powersave governor which scales up when needed but saves power at idle
      # Alternative: "ondemand" - more responsive but slightly higher idle power
      cpuFreqGovernor = if env.deviceType != "laptop" then "performance" else null;
    };

    networking.networkmanager = lib.mkIf (env.deviceType == "server") {
      wifi.powersave = false;
    };

    # Enable CPU idle states (C-states) for better power savings at idle
    # This allows CPUs to enter deeper sleep states when idle
    # Note: kernelParams merge automatically, so this will add to any existing params
    boot = lib.mkIf (env.deviceType == "server") {
      kernelParams = [
        "intel_idle.max_cstate=1" # Absolute limit on CPU sleep depth
        "pcie_aspm=off" # Disable PCIe power management globally
        "e1000e.SmartPowerDownEnable=0"
        "iwlwifi.power_save=0" # Disable Wi-Fi power saving
      ];
      extraModprobeConfig = ''
        options e1000e SmartPowerDownEnable=0
        options iwlwifi power_save=0 d0i3_disable=1 uapsd_disable=1
      '';
    };

    systemd.services = lib.mkIf (env.deviceType == "server") {
      # The "Kill Switch" for Ethernet Power Management
      # This disables TSO (TCP Segmentation Offload).
      # Buggy Intel cards like yours often crash when TSO is on during power shifts.
      stabilize-ethernet = {
        description = "Disable buggy hardware offloading on eno1";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.ethtool}/bin/ethtool -K eno1 tso off gso off gro off";
          RemainAfterExit = true;
        };
      };
    };
  };
}
