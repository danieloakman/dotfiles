# Power management configuration, including CPU frequency scaling, power profiles, etc
{ env, lib, pkgs, ... }:
{
  services = {
    # Better scheduling for CPU cycles:
    system76-scheduler.settings.cfsProfiles.enable = true;

    # Prevents overheating and works well with intel CPUs;
    thermald.enable = true;

    # Disable GNOMEs power management for laptops
    power-profiles-daemon.enable = env.deviceType == "laptop";

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

  powerManagement = {
    # Enable powertop to see power usage
    powertop.enable = true;

    # Server-specific power management options
    # For servers, use powersave governor which scales up when needed but saves power at idle
    # Alternative: "ondemand" - more responsive but slightly higher idle power
    cpuFreqGovernor = if env.deviceType == "server" then "ondemand" else null;
  };

  environment.systemPackages = with pkgs; [ powertop ];

  # Enable CPU idle states (C-states) for better power savings at idle
  # This allows CPUs to enter deeper sleep states when idle
  # Note: kernelParams merge automatically, so this will add to any existing params
  boot = lib.mkIf (env.deviceType == "server") {
    kernelParams = [
      # 1. Stop the CPU from falling into deep sleep 'traps'
      "intel_idle.max_cstate=1"

      # 2. Disable Ethernet Power Management (Fixes the ULP error)
      "e1000e.SmartPowerDownEnable=0"

      # 3. Disable PCIe Active State Power Management (Often fixes iwlwifi/e1000e conflicts)
      "pcie_aspm=off"
    ];
    extraModprobeConfig = ''
      options iwlwifi power_save=0
      options e1000e IntMode=1,1,1
    '';
  };

}
