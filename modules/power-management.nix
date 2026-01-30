# Power management configuration, including CPU frequency scaling, power profiles, etc
{ env, lib, ... }:
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

  # Enable powertop to see power usage
  powerManagement.powertop.enable = true;

  # Server-specific power management options
  # For servers, use powersave governor which scales up when needed but saves power at idle
  # Alternative: "ondemand" - more responsive but slightly higher idle power
  powerManagement.cpuFreqGovernor = if env.deviceType == "server" then "powersave" else null;

  # Enable CPU idle states (C-states) for better power savings at idle
  # This allows CPUs to enter deeper sleep states when idle
  # Note: kernelParams merge automatically, so this will add to any existing params
  boot.kernelParams = lib.mkIf (env.deviceType == "server") [
    # Limit to C1 or C4 for stability. 0 is often too aggressive.
    "intel_idle.max_cstate=1" 
    # Also consider adding this to prevent the Ethernet ULP error:
    "e1000e.SmartPowerDownEnable=0"
  ];
}
