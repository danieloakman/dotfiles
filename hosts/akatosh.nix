# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').

{ env, config, lib, modulesPath, ... }:
let
  nvidiaPkg = config.boot.kernelPackages.nvidiaPackages.mkDriver {
    version = "580.126.09";
    sha256_64bit = "sha256-TKxT5I+K3/Zh1HyHiO0kBZokjJ/YCYzq/QiKSYmG7CY=";
    settingsSha256 = "sha256-4SfCWp3swUp+x+4cuIZ7SA5H7/NoizqgPJ6S9fm90fA=";
    persistencedSha256 = "sha256-J1UwS0o/fxz45gIbH9uaKxARW+x4uOU1scvAO4rHU5Y=";
  };
  wallpaperPath = ../files/assets/akatosh-wallpaper.jpeg;
in
{
  my = {
    desktop = {
      hyprland = {
        enable = true;
        monitors = [
          "DVI-D-1, 1920x1080, 0x0, 1.0"
          "DP-2, 3440x1440@144.00Hz, 1920x0, 1.0"
          "HDMI-A-1, 1920x1080, 5360x0, 1.0"
        ];
        # This host basically links its 3 monitors to 3 workspaces:
        workspaces = [
          "1, monitor:DVI-D-1"
          "2, monitor:DP-2"
          "3, monitor:HDMI-A-1"
        ];
        # Window rules — hyprlang `windowrule` (windowrulev2 / class:… prefix were removed upstream)
        windowRules = [
          "workspace 1, match:class ^(vivaldi-bin)$"
          "workspace 1, match:class ^(vivaldi)$"
          "workspace 1, match:class ^(chromium)$"
          "workspace 1, match:class ^(chrome)$"
          "workspace 1, match:class ^(firefox)$"
          "workspace 1, match:class ^(google-chrome)$"
          "workspace 2, match:class ^(Cursor)$"
          "workspace 2, match:class ^(code)$"
          "workspace 3, match:class ^(Spotify)$"
          "workspace 2, match:class ^(obsidian)$"
          "workspace 3, match:class ^(Discord)$"
          "workspace 3, match:class ^(Steam)$"
        ];
        hyprpaper.wallpaper = wallpaperPath;
      };
      uiShell = "noctalia-v5";
      noctaliaV5 = {
        bar.monitors = [ "DP-2" ];
        location.address = "Sydney";
      };
      # gnome.enable = true;
    };
    programs = {
      agents = {
        enable = true;
        sandbox.enable = true;
      };
      devPkgs.enable = true;
      jsPackageSecurity.enable = true;
      claude-code.enable = true;
      rtk.enable = true;
      herdr.enable = true;
      hunk.enable = true;
      cursor.enable = true;
      opencode = {
        enable = true;
        providers = {
          cursor.enable = true;
          claude.enable = true;
          llama-cpp.enable = true;
        };
      };
      games.enable = true;
      gws.enable = true;
      localsend.enable = true;
      obsidian.enable = true;
      desktopPkgs.enable = true;
      kitty.enable = true;
      rofi.enable = true;
      ydotool.enable = true;
      micro = {
        isDefaultEditor = true;
      };
      comma.enable = true;
      ms-apps.enable = true;
    };
    scripts.bun.enable = true;
    services = {
      stylix = {
        enable = true;
        wallpaper = wallpaperPath;
      };
      docker.enable = true;
      headroom.enable = true;
      llama-cpp = {
        enable = true;
        cpuCoreCount = 6;
        gpuLayerCount = 99;
        models = {
          # Example of how to add a model from Hugging Face using fetchurl. So this would download at build time, taking a while to download
          # someModel = {
          #   path = pkgs.fetchurl {
          #     url = "https://huggingface.co/bartowski/DeepSeek-R1-Distill-Qwen-7B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-7B-Q6_K.gguf";
          #     hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
          #   };
          # };
          "Qwen2.5-coder-1.5b-instruct-Q8_0" = {
            path = "/models/qwen2.5-coder-1.5b-instruct-q8_0.gguf";
            contextSize = 32768; # Qwen2.5-Coder-1.5B-Instruct native config
          };
          "DeepSeek-R1-Distill-Qwen-7B-Q6_K" = {
            path = "/models/DeepSeek-R1-Distill-Qwen-7B-Q6_K.gguf";
            contextSize = 131072; # deepseek-ai/DeepSeek-R1-Distill-Qwen-7B max_position_embeddings
          };
          "Qwen2.5-VL-7B-Instruct-Q6_K" = {
            path = "/models/Qwen2.5-VL-7B-Instruct-Q6_K.gguf";
            contextSize = 32768; # Qwen2.5-VL-7B-Instruct native config
          };
        };
      };
      wakeonlan.enable = true;
      syncthing.enable = true;
      pia.enable = true;
    };
  };
  systemd.tmpfiles.rules = [ "d /models 0755 root root -" ]; # Create the models directory in /models

  boot = {
    initrd = {
      availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "usbhid" "sd_mod" ];
      kernelModules = [ "nvidia" ];
    };
    kernelModules = [ "kvm-intel" ];
    kernelParams = [
      # "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
      # Removed NVreg_PreserveVideoMemoryAllocations as it conflicts with suspend
      # If you need to preserve video memory, you'll need to configure NVIDIA
      # power management differently (see NVIDIA driver README)
      "module_blacklist=i915"
    ];
    extraModulePackages = [ nvidiaPkg ];
    # Limit the number of generations to 3
    # loader.grub.configurationLimit = 3;
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/0725ce27-35ca-4988-9ee3-007127d7db15";
      fsType = "ext4";
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/395D-FC06";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };
    "/run/media/HDD_1" = {
      device = "/dev/disk/by-uuid/8C48AC3148AC1BC8";
      fsType = "ntfs";
    };
    "/run/media/HDD_2" = {
      device = "/dev/disk/by-uuid/5608D2D708D2B4E9";
      fsType = "ntfs";
    };
    "/run/media/HDD_3" = {
      device = "/dev/disk/by-uuid/1874480F7447EE56";
      fsType = "ntfs";
    };
    "/run/media/HDD_4" = {
      device = "/dev/disk/by-uuid/788189FD487EDAE2";
      fsType = "ntfs";
    };
  };

  swapDevices = [ ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp0s31f6.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp4s0.useDHCP = lib.mkDefault true;

  nixpkgs.config.nvidia.acceptLicense = true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  imports = [
    # Include the results of the hardware scan.
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # Bootloader
  boot.loader = {
    efi.canTouchEfiVariables = true;
    grub = {
      device = "nodev";
      enable = true;
      efiSupport = true;
      useOSProber = true;
    };
  };

  networking.hostName = "akatosh"; # Define your hostname.

  home-manager.users.${env.user} = {
    services.remmina = {
      enable = true; # RDP client for connecting to remote desktops
      systemdService.enable = false;
    };
  };

  hardware = {
    enableRedistributableFirmware = true;

    # This might not be needed, as it's to do with cpu graphics, which this system doesn't have. Leave it for now.
    graphics.enable = true;
    graphics.enable32Bit = true;

    # See https://nixos.wiki/wiki/Nvidia for more information.
    nvidia = {
      modesetting.enable = true;
      # GTX 1080 Ti + pinned 580.126.09 driver: disable GSP because this build does not provide GSP firmware.
      gsp.enable = false;
      # Enable power management for suspend to work properly
      # Fine-grained requires PRIME offload (needs Turing+ GPU), so use regular PM
      powerManagement.enable = true;
      package = nvidiaPkg;
      open = false; # Must be false as GTX 1080Ti doesn't support the open module
      nvidiaSettings = true;
    };
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  # Configure remote builders
  nix.buildMachines = [
    {
      hostName = "mara";
      system = "x86_64-linux";
      maxJobs = 3;
      speedFactor = 2;
      supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
      mandatoryFeatures = [ ];
    }
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
}
