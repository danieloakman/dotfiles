# Open common local-dev server ports on workstation firewalls.
# Classification: flake `deviceType` (desktop/laptop vs server), not
# `my.profiles.dev-workstation` (mara enables that profile but is a server).
{ config, lib, env, ... }:
let
  cfg = config.my.dev.openPorts;
in
{
  options.my.dev.openPorts = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = env.deviceType != "server";
      description = ''
        Open common development-server TCP (and a few UDP) ports in the NixOS
        firewall. Defaults on for desktop/laptop hosts and off for servers.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall = {
      allowedTCPPorts = [
        4173 # Vite preview
        4200 # Angular
        5555 # Android adb wireless
        6006 # Storybook
        8888 # Jupyter
        9222 # Chrome DevTools / Hermes CDP
      ];
      allowedTCPPortRanges = [
        { from = 3000; to = 3010; } # Node / Next / Convex
        { from = 5000; to = 5005; } # Flask and similar
        { from = 5173; to = 5180; } # Vite
        { from = 8000; to = 8010; } # Generic HTTP
        { from = 8080; to = 8090; } # Generic + Metro 8081
        { from = 9000; to = 9002; } # Generic app servers
        { from = 19000; to = 19006; } # Expo
      ];
      # Expo Go LAN discovery can use UDP in the same range as the TCP ports.
      allowedUDPPortRanges = [
        { from = 19000; to = 19006; }
      ];
    };
  };
}
