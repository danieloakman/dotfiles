# Power management configuration, including CPU frequency scaling, power profiles, etc
{ isLaptop, helpers, ... }:
{
  # Better scheduling for CPU cycles:
  services.system76-scheduler.settings.cfsProfiles.enable = true;
  # Prevents overheating and works well with intel CPUs;
  services.thermald.enable = true;


  # Enable powertop for laptops
  powerManagement.powertop.enable = isLaptop;
  # Disable GNOMEs power management for laptops
  services.power-profiles-daemon.enable = helpers.not isLaptop;

  # Enable TLP for laptops
  services.tlp = {
    enable = isLaptop;
    settings = {
      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
    };
  };
}
