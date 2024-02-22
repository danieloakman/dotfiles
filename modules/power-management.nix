{ isLaptop, pkgs, ... }:
{
  # Better scheduling for CPU cycles:
  services.system76-scheduler.settings.cfsProfiles.enable = true;
  # Prevents overheating and works well with intel CPUs;
  services.thermald.enable = true;
  # Enable powertop
  powerManagement.powertop.enable = isLaptop;
  # Disable GNOMEs power management
  services.power-profiles-daemon.enable = if isLaptop then false else true;

  environment.systemPackages = with pkgs; [
    rustc
  ];

  services.tlp =
    if isLaptop then {
      enable = true;
      settings = {
        CPU_BOOST_ON_AC = 1;
        CPU_BOOST_ON_BAT = 0;
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      };
    } else null;
}
