# This module directory is for long running services that are intended to run continuously.
# Like jellyfin, stirling-pdf, etc.
_: {
  imports = [
    ./adblocker.nix
    # ./caddy.nix
    ./cockpit.nix
    ./copyparty.nix
    ./homepage.nix
    ./immich.nix
    # ./n8n.nix
    ./stirling-pdf.nix
    ./streaming.nix
  ];

  services.tailscale.useRoutingFeatures = "server";
  streaming.enable = true; # Enables streaming.nix module
}
