# This module directory is for long running services that are intended to run continuously.
# Like jellyfin, stirling-pdf, etc.
_: {
  imports = [
    ./adblocker.nix
    # ./caddy.nix
    ./cockpit.nix
    # ./cursor-agent-http # Couldn't get this to work when running in systemd, disabling for now
    # ./copyparty.nix # Very ram instensive, disabling for now
    ./homepage.nix
    ./immich.nix
    ./llama-cpp.nix
    ./n8n.nix
    # ./ollama.nix
    ./stirling-pdf.nix
    ./paperless.nix
    ./streaming.nix
  ];

  services.tailscale.useRoutingFeatures = "server";
}
