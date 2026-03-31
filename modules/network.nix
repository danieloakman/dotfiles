{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    # Including these because I noticed the nm-* icons were missing without them.
    networkmanager
    networkmanager-openvpn
    networkmanagerapplet
  ];

  networking = {
    # Enable networking
    networkmanager = {
      enable = true;
      plugins = with pkgs; [
        networkmanager-openvpn
      ];
      settings = {
        connection-wifi = {
          "match-device" = "type:wifi";
          "ipv4.route-metric" = 600;
          "ipv6.route-metric" = 600;
        };
        # Prefer Ethernet over Wi-Fi for default route.
        connection-ethernet = {
          "match-device" = "type:ethernet";
          "ipv4.route-metric" = 100;
          "ipv6.route-metric" = 100;
        };
      };
    };
    # wireless.enable = true;  # Enables wireless support via wpa_supplicant.
    # Configure network proxy if necessary
    # proxy.default = "http://user:password@proxy:port/";
    # proxy.noProxy = "127.0.0.1,localhost,internal.domain";

    firewall = {
      enable = true;
      # Allow OpenSSH and other dev related ports accessible through firewall
      allowedTCPPorts = [ 4200 4000 ];
      allowedTCPPortRanges = [
        { from = 3000; to = 3010; }
        { from = 8000; to = 8100; }
        { from = 5170; to = 5180; } # typically 5173 for vite, and the same idea for the one below
        { from = 4170; to = 4180; }
        { from = 8080; to = 8090; } # Expo dev server uses these, as well as other common servers
      ];
      # Open ports in the firewall for tiny.work:
      trustedInterfaces = [ "tun0" "tun" ]; # For tiny.work VPN
      allowedUDPPorts = [
        443 # tiny.work VPN
        1197 # For PIA VPN
        1198 # For PIA VPN
      ];
      # checkReversePath = false;
    };
  };

  # Network manager connection applet:
  programs.nm-applet = {
    enable = true;
    indicator = true;
  };
}
