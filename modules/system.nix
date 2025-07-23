# Base configuration for every user, i.e. the whole system.

{ inputs, pkgs, env, ... }:
{
  networking = {
    # Enable networking
    networkmanager.enable = true;
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
      # Enable the X11 windowing system.
      # This is apparently needed on wayland systems as well. Quite strange. It's worth trying to disable it in the future
      # to see if it works without it.
      enable = true;
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
      # Enable experimental nix features:
      experimental-features = [ "nix-command" "flakes" ];
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
  # sound.enable = true;
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment = {
    shells = with pkgs; [ zsh ];

    localBinInPath = true;

    systemPackages = with pkgs; [
      #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
      git
      wget
      btop
      fastfetch
      ((if env.isOnWayland then pass-wayland else pass).withExtensions (ext: with ext; [
        pass-otp
        pass-update
        pass-checkup
        pass-audit # TODO
      ]))
      (if env.isOnWayland then pass-wayland else pass)
      # Was trying out https://github.com/NixOS/nixpkgs/issues/104249 for passmenu fix:
      # rofi-pass
      # pinentry-curses
      # pinentry-qt
      eza
      bat
      lazygit
      fzf
      neovim
      sops
      age
      gh
      # gh-dash
      unzip
      zip
      jq
      rsync

      # Network utilities
      wakeonlan
      (pkgs.writeShellScriptBin "wake-akatosh" ''
        wakeonlan 4c:ed:fb:96:ee:3d
      '')

      # Nix specific:
      nil # Nix LSP
      nh # Nix helper
      nixpkgs-fmt # A formatter for .nix files.

      # These were used for trying to get `passmenu` to work, but it just doesn't with gnome & wayland:
      (if env.isOnWayland then dmenu-wayland else dmenu)
      (if env.isOnWayland then ydotool else xdotool)

      starship
      curl
      xclip
      # logkeys # Was testing whether I could log laptop buttons or not
      inputs.openvpn24.legacyPackages.${system}.openvpn_24 # Needed specifically this version for tiny.work
      # inputs.devenv.packages.${system}.devenv # No long use devenv. Just use nix shell instead.
    ] ++ (if env.isOnWayland then [
      wl-clipboard
    ] else [ ]);
  };

  programs = {
    zsh.enable = true;
    gnupg.agent.enable = true;
    nix-ld = {
      enable = true;
      libraries = (with pkgs; [
        # Add any missing dynamic libraries for unpackaged programs
        # here, NOT in environment.systemPackages
        # TODO: move stuff from auxilis FHS shell to here, probably.
        # TODO: put stuff in here that's needed to install playwright
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
      ]) ++ (with pkgs.xorg; [
        libX11
        libXext
        libSM
      ]);
    };

    localsend = {
      enable = true;
      openFirewall = true;
    };

    nh = {
      enable = true;
      clean.enable = true;
      clean.extraArgs = "--keep-since 14d --keep 3";
      flake = "/home/${env.user}/repos/personal/dotfiles";
    };

    # Enables the `browserpass` extension for chromium, firefox, google-chrome, vivaldi browsers.
    browserpass.enable = true;

    # Some programs need SUID wrappers, can be configured further or are
    # started in user sessions.
    # mtr.enable = true;
  };

  fonts.packages = with pkgs; [
    nerd-fonts.fira-mono
    nerd-fonts.fira-code
  ];

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
}
