# Power management configuration, including CPU frequency scaling, power profiles, etc
{ env, lib, pkgs, ... }: {
  config = env.selectPlatform {
    linux = {
      services = {
        # Better scheduling for CPU cycles:
        system76-scheduler.settings.cfsProfiles.enable = true;

        # Prevents overheating and works well with intel CPUs;
        thermald.enable = true;

        # Disable GNOMEs power management for laptops
        power-profiles-daemon.enable = env.deviceType != "laptop";

        # Enable TLP for laptops
        tlp = {
          enable = env.deviceType == "laptop";
          settings = {
            CPU_BOOST_ON_AC = 1;
            CPU_BOOST_ON_BAT = 0;
            CPU_SCALING_GOVERNOR_ON_AC = "performance";
            CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
            # Limit battery charging to 85% to extend battery lifespan
            START_CHARGE_THRESH_BAT0 = 60;
            STOP_CHARGE_THRESH_BAT0 = 85;
          };
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
  };
}
