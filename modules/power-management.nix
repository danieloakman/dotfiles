# Power management configuration, including CPU frequency scaling, power profiles, etc
{ env, ... }:
{
  services = {
    # Better scheduling for CPU cycles:
    system76-scheduler.settings.cfsProfiles.enable = true;

    # Prevents overheating and works well with intel CPUs;
    thermald.enable = true;

    # Disable GNOMEs power management for laptops
    power-profiles-daemon.enable = !env.isLaptop;

    # Enable TLP for laptops
    tlp = {
      enable = env.isLaptop;
      settings = {
        CPU_BOOST_ON_AC = 1;
        CPU_BOOST_ON_BAT = 0;
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
        # TODO: limit charging to battery to 85%
      };
    };
  };

  # Enable powertop for laptops
  powerManagement.powertop.enable = env.isLaptop;
}
