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
    profiles.dev-workstation.enable = true;
    desktop = {
      hyprland = {
        enable = true;
        monitors = [
          "DVI-D-1, 1920x1080, 0x0, 1.0"
          "DP-2, 3440x1440@144.00Hz, 1920x0, 1.0"
          "HDMI-A-1, 1920x1080, 5360x0, 1.0"
        ];
        # One workspace per monitor
        workspaces = [
          "1, monitor:DVI-D-1"
          "2, monitor:DP-2"
          "3, monitor:HDMI-A-1"
        ];
        # hyprlang `windowrule` (windowrulev2 / class:… prefix were removed upstream)
        window-rules = [
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
      ui-shell = "noctalia-v5";
      noctalia-v5 = {
        bar.monitors = [ "DP-2" ];
        location.address = "Sydney";
      };
      # gnome.enable = true;
    };
    programs = {
      opencode = {
        enable = true;
        providers = {
          cursor.enable = true;
          claude.enable = true;
          llama-cpp.enable = true;
        };
      };
      games.enable = true;
      desktop-pkgs.enable = true;
      comma.enable = true;
      ms-apps.enable = true;
    };
    services = {
      stylix = {
        enable = true;
        wallpaper = wallpaperPath;
      };
      docker.enable = true;
      headroom.enable = true;
      llama-cpp = {
        enable = true;
        cpu-core-count = 6;
        gpu-layer-count = 99;
        models = {
          "Qwen2.5-coder-1.5b-instruct-Q8_0" = {
            path = "/models/qwen2.5-coder-1.5b-instruct-q8_0.gguf";
            context-size = 32768; # Qwen2.5-Coder-1.5B-Instruct native config
          };
          "DeepSeek-R1-Distill-Qwen-7B-Q6_K" = {
            path = "/models/DeepSeek-R1-Distill-Qwen-7B-Q6_K.gguf";
            context-size = 131072; # deepseek-ai/DeepSeek-R1-Distill-Qwen-7B max_position_embeddings
          };
          "Qwen2.5-VL-7B-Instruct-Q6_K" = {
            path = "/models/Qwen2.5-VL-7B-Instruct-Q6_K.gguf";
            context-size = 32768; # Qwen2.5-VL-7B-Instruct native config
          };
        };
      };
      wakeonlan.enable = true;
      syncthing.enable = true;
      pia.enable = true;
    };
  };
  systemd.tmpfiles.rules = [ "d /models 0755 root root -" ];

  boot = {
    initrd = {
      availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "usbhid" "sd_mod" ];
      kernelModules = [ "nvidia" ];
    };
    kernelModules = [ "kvm-intel" ];
    kernelParams = [
      # NVreg_PreserveVideoMemoryAllocations conflicts with suspend; use powerManagement instead
      "module_blacklist=i915"
    ];
    extraModulePackages = [ nvidiaPkg ];
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

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.config.nvidia.acceptLicense = true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.loader = {
    efi.canTouchEfiVariables = true;
    grub = {
      device = "nodev";
      enable = true;
      efiSupport = true;
      useOSProber = true;
    };
  };

  networking.hostName = "akatosh";

  home-manager.users.${env.user} = {
    services.remmina = {
      enable = true;
      systemdService.enable = false;
    };
  };

  hardware = {
    enableRedistributableFirmware = true;

    # Possibly unnecessary without iGPU; leave enabled for now.
    graphics.enable = true;
    graphics.enable32Bit = true;

    # https://nixos.wiki/wiki/Nvidia
    nvidia = {
      modesetting.enable = true;
      # Pinned 580.126.09 has no GSP firmware for this GTX 1080 Ti build.
      gsp.enable = false;
      # Fine-grained PM needs Turing+ PRIME offload; use regular PM for suspend.
      powerManagement.enable = true;
      package = nvidiaPkg;
      open = false; # GTX 1080 Ti does not support the open module
      nvidiaSettings = true;
    };
  };

  services.xserver.videoDrivers = [ "nvidia" ];

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

  system.stateVersion = "23.11";
}
