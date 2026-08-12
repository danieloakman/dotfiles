{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    # Including these because I noticed the nm-* icons were missing without them.
    networkmanager
    networkmanager-openvpn
    networkmanagerapplet

    nixos-firewall-tool
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
      # checkReversePath = false;
    };
  };

  # Network manager connection applet:
  programs.nm-applet = {
    enable = true;
    indicator = true;
  };
}
