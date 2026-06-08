# Base configuration for every user, i.e. the whole system.

{ inputs, pkgs, env, system, ... }:
let
  # Import pinned nixpkgs directly so we don't go through its flake `legacyPackages`
  # (that path can touch deprecated `pkgs.system` on current nixpkgs during eval).
  openvpn24Pkgs = import inputs.openvpn24 { inherit system; };
in
{
  config = env.selectPlatform {
    any = {
      # Necessary for using flakes on every platform/system:
      nix.settings.experimental-features = "nix-command flakes";

      nixpkgs.config = {
        allowUnfree = true;
        # Any flake/input that instantiates nixpkgs for x86_64-darwin otherwise prints the26.05 deprecation notice.
        allowDeprecatedx86_64Darwin = true;
      };

      fonts.packages = with pkgs; [
        nerd-fonts.fira-mono
        nerd-fonts.fira-code
      ];
    };

    linux = {
      # Enable bluetooth
      hardware.bluetooth = {
        enable = true;
        settings = {
          General = {
            Name = "Hello";
            ControllerMode = "dual";
            FastConnectable = "true";
            Experimental = "true";
          };
          Policy = {
            AutoEnable = "true";
          };
        };
      };

      # Set your time zone.
      time.timeZone = "Australia/Sydney";

      # Select internationalisation properties.
      i18n.defaultLocale = "en_GB.UTF-8";

      i18n.extraLocaleSettings = {
        LC_ADDRESS = "en_AU.UTF-8";
        LC_IDENTIFICATION = "en_AU.UTF-8";
        LC_MEASUREMENT = "en_AU.UTF-8";
        LC_MONETARY = "en_AU.UTF-8";
        LC_NAME = "en_AU.UTF-8";
        LC_NUMERIC = "en_AU.UTF-8";
        LC_PAPER = "en_AU.UTF-8";
        LC_TELEPHONE = "en_AU.UTF-8";
        LC_TIME = "en_AU.UTF-8";
      };

      services = {
        xserver = {
          # Configure keymap in X11
          xkb = {
            layout = "us";
            variant = "";
          };
        };
        # Enable CUPS to print documents.
        printing.enable = true;
      };

      nix = {
        settings = {
          trusted-users = [ "root" "@wheel" ];
          auto-optimise-store = true;
          # Enable distributed builds and use substitutes:
          builders-use-substitutes = true;
        };
        # Optimise automaticaly see: https://nixos.wiki/wiki/Storage_optimization#Automatic
        optimise.automatic = true;
        # Run garbage collection automatically
        # Disable to not conflict with `programs.nh.clean`
        # gc = {
        #   automatic = true;
        #   dates = "weekly";
        #   options = "--delete-older-than 14d";
        #   persistent = true; # Default is true, but just to be explicit.
        # };
      };


      # Enable sound with pipewire.
      services.pulseaudio.enable = false;
      security.rtkit.enable = env.deviceType != "server";
      services.pipewire = {
        enable = env.deviceType != "server";
        alsa = {
          enable = true;
          support32Bit = true;
        };
        pulse.enable = true;
        # If you want to use JACK applications, uncomment this
        #jack.enable = true;

        # use the example session manager (no others are packaged yet so this is enabled by default,
        # no need to redefine it in your config for now)
        #media-session.enable = true;
      };

      # Enable touchpad support (enabled default in most desktopManager).
      # services.xserver.libinput.enable = true;

      # Enable KVM for virtualization (needed for Android emulator)
      virtualisation.libvirtd.enable = false; # We don't need libvirtd, just KVM modules
      boot.kernelModules = [ "kvm-intel" ]; # Load KVM module for Intel CPUs

      # List packages installed in system profile. To search, run:
      # $ nix search wget
      environment = {
        localBinInPath = true;

        # TODO: move most of this to any platform:
        systemPackages = with pkgs; [
          #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
          git
          wget
          fastfetch
          # pinentry-curses
          # pinentry-qt
          eza
          bat
          fzf
          sops
          age
          gh
          # gh-dash
          unzip
          zip
          jq
          rsync
          home-manager

          # Network utilities
          wakeonlan
          (pkgs.writeShellScriptBin "wake-akatosh" ''
            ${lib.getExe wakeonlan} 4c:ed:fb:96:ee:3d
          '')
          (pkgs.writeShellScriptBin "wake-mara" ''
            ${lib.getExe wakeonlan} f8:b4:6a:b3:02:ce
          '')

          # Nix specific:
          nil # Nix LSP
          nh # Nix helper
          nixpkgs-fmt # A formatter for .nix files.
          statix # A linter for .nix files.

          # These were used for trying to get `passmenu` to work, but it just doesn't with gnome & wayland:
          (if env.isOnWayland then dmenu-wayland else dmenu)

          starship
          curl
          xclip
          # logkeys # Was testing whether I could log laptop buttons or not
          openvpn24Pkgs.openvpn_24 # Needed specifically this version for tiny.work
          # inputs.devenv.packages.${system}.devenv # No long use devenv. Just use nix shell instead.
        ] ++ (if env.isOnWayland then [
          wl-clipboard
        ] else [
          xdotool
        ]);
      };

      programs = {
        gnupg.agent.enable = true;
        nix-ld = {
          enable = true;
          libraries = (with pkgs; [
            # Add any missing dynamic libraries for unpackaged programs
            # here, NOT in environment.systemPackages
            # TODO: move stuff from auxilis FHS shell to here, probably.
            # tesseract
            # python310
            # python310Packages.pip
            # python310Packages.virtualenv
            # swig
            stdenv
            stdenv.cc.cc
            stdenv.cc.cc.lib
            glibc
            glib.dev
            libffi
            # ffmpeg
            libsmf
            libGL
            libz
            libzip
            libgcc
            zlib
            pango
            fontconfig
            opencv
            cmake
            pixman
            cairo
            libjpeg
            giflib
            librsvg
          ]) ++ (with pkgs; [
            libx11
            libxext
            libsm
          ]);
        };

        # Some programs need SUID wrappers, can be configured further or are
        # started in user sessions.
        # mtr.enable = true;
      };

      # Symbolic link /bin/sh to /bin/bash for compatibility with things that expect bash to be at /bin/bash:
      system.activationScripts.binbash = {
        deps = [ "binsh" ];
        # /bin/sh is apparently bash, or at least can dynamically swap between bash and sh depending on command used at argv[0]
        text = ''
          # Check if /bin/bash is already a symlink to /bin/sh
          if [ ! -L /bin/bash ]; then
            # If not, then create the symlink
            ln -s /bin/sh /bin/bash
          fi
        '';
      };
    };

    darwin = {
      # TODO: fill with darwin specific config.
    };
  };
}
