# This module directory is for long running services that are intended to run continuously.
# Like jellyfin, stirling-pdf, etc.
_: {
  imports = [
    ./adblocker.nix
    # ./caddy.nix
    ./cockpit.nix
    ./cursor-agent-http
    # ./copyparty.nix # Very ram instensive, disabling for now
    ./homepage.nix
    ./immich.nix
    ./llama-cpp.nix
    ./n8n.nix
    # ./ollama.nix
    ./stirling-pdf.nix
    ./streaming.nix
  ];

  services.tailscale.useRoutingFeatures = "server";
}
