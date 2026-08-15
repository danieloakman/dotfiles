# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, lib, modulesPath, ... }:
{
  imports = [
    # Include the results of the hardware scan.
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  my = {
    profiles.dev-workstation.enable = true;
    programs = {
      opencode = {
        enable = true;
        web.enable = true;
        providers = {
          cursor.enable = true;
          claude.enable = true;
        };
      };
      herdr.collie = {
        enable = true;
        # Tailscale login that may drive agents (see Collie README → security).
        trusted-user = "doakman94@gmail.com";
        # Exposed via `tailscale-svc-herdr-collie-up` (not MagiDNS root serve).
        public-hosts = [ "herdr-collie.dinosaur-crocodile.ts.net" ];
        public-url = "https://herdr-collie.dinosaur-crocodile.ts.net";
        web-push.enable = true;
      };
      # mobile-dev.enable = false;
      # tmux.enable = true;
      # zellij = {
      #   enable = true;
      #   auto-start.enable = true;
      # };
    };
    services = {
      dns-ad-block.enable = true;
      cockpit = let port = 19090; in {
        enable = true;
        inherit port;
        allowed-origins = [
          "https://mara-cockpit.dinosaur-crocodile.ts.net"
        ];
      };
      docker.enable = true;
      headroom.enable = true;
      homepage = let port = 9092; in {
        inherit port;
        enable = true;
        allowed-hosts = "${config.networking.hostName}:${toString port},localhost:${toString port},homepage.dinosaur-crocodile.ts.net";
      };
      immich = {
        enable = true;
        media-location = "/run/media/HDD_1/immich";
      };
      # n8n.enable = true;
      paperless = {
        enable = true;
        domain = "paperless.dinosaur-crocodile.ts.net";
        media-dir = "/run/media/HDD_1/paperless";
      };
      postiz = let port = 10322; in {
        enable = false;
        inherit port;
        # public-base-url = "https://postiz.dinosaur-crocodile.ts.net";
        public-base-url = "http://mara:${toString port}";
        jwt-secret-file = config.sops.secrets.postiz_jwt_secret.path;
      };
      # Soft-remediate internet/Tailscale failures; reboot up to 3 times then stay up.
      connectivity-watchdog.enable = true;
      pia.enable = true;
      qbittorrent = {
        enable = true;
        download-dir = "/run/media/HDD_1/Downloads";
        vpn = {
          enable = true;
          external-interface = "eno1";
          # DE Streaming Optimized — AU Sydney blackholed apibay/TPB search.
          remote = "de-germany-so.privacy.network";
        };
      };
      stirling-pdf.enable = true;
      streaming.jellyfin.enable = true;
      syncthing.enable = true;
      tailscale = {
        enable-as-exit-node = true;
        use-routing-features = "server";
      };
      tandoor.enable = false;
      # wakeonlan.enable = true; # TODO: try this out
    };
  };

  boot = {
    initrd = {
      availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod" ];
      kernelModules = [ ];
    };
    kernelModules = [ "kvm-intel" ];
    extraModulePackages = [ ];
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/57e37ff0-9c7c-4aa4-9955-cb7ad0d7cca3";
      fsType = "ext4";
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/265B-6120";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };
    "/run/media/HDD_1" = {
      device = "/dev/disk/by-uuid/567A58A4260BD810";
      fsType = "ntfs";
    };
  };
  systemd.tmpfiles.rules = [
    "d /run/media/HDD_1 0770 root storage -"
  ];

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 8192; # MB
    }
  ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.eno1.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp0s20f3.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  # Bootloader.
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  networking.hostName = "mara"; # Define your hostname.

  # Configure console keymap
  console.keyMap = "us";

  # Configure remote builders
  nix.buildMachines = [
    {
      hostName = "akatosh";
      system = "x86_64-linux";
      maxJobs = 8;
      speedFactor = 2;
      supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
      mandatoryFeatures = [ ];
    }
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?

  specialisation = {
    remote-desktop.configuration = {
      system.nixos.tags = [ "remote-desktop" ];
      my.services.remote-desktop.enable = true;
    };
  };
}
