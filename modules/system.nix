# Base configuration for every user, i.e. the whole system.

{ inputs, config, lib, pkgs, env, ... }:
{
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Enable bluetooth
  hardware.bluetooth.enable = true;

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

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  nix = {
    # Enable experimental nix features:
    settings.experimental-features = [ "nix-command" "flakes" ];
    # Optimise automaticaly see: https://nixos.wiki/wiki/Storage_optimization#Automatic
    optimise.automatic = true;
    # Run garbage collection automatically
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };


  # Enable sound with pipewire.
  sound.enable = true;
  hardware.pulseaudio.enable = false;
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
      neofetch
      pass-wayland
      # Was trying out https://github.com/NixOS/nixpkgs/issues/104249 for passmenu fix:
      # rofi-pass
      pinentry-curses
      pinentry-qt
      # rtx # Couldn't get this to work in nixos, now installing the binaries it supports through nixpkgs
      eza
      bat
      thefuck
      lazygit
      fzf
      neovim
      gh
      # gh-dash
      unzip
      zip
      jq
      rsync
      nixpkgs-fmt # A formatter for .nix files.
      gnat13 # Provides gcc, g++, etc
      # libgcc # Unsure why this doesn't gives gcc, g++, etc as programs to use, but it don't
      gnumake
      nurl

      # TODO: remove dev related things like go and rust to a devenv instead.
      # Node can stay as it's needed for running scripts

      # Rust:
      # cargo
      # rustup

      # Go related packages:
      # go
      # gopls
      # delve
      # go-tools

      # Node and Javascript related packages:
      nodejs_20
      # yarn
      nodePackages_latest.pnpm
      bun

      python3
      (python3.withPackages (ps: with ps; [
        # TODO: comment out most of this in favour of using a devenv and locally installed packages instead
        pip
        # pipx
        # black
        # pytest
        # pylint
        # mypy
        # mypy-extensions
        # boto
        # boto3
        # urllib3
        # more-itertools
        # numpy
        # certifi
        # typing-extensions
        # (
        #   buildPythonPackage rec {
        #     pname = "aws-sso-util";
        #     version = "4.32.0";
        #     # Can use `nurl` next time to use `fetchFromGithub`
        #     src = fetchurl {
        #       url = "https://github.com/benkehoe/aws-sso-util/releases/download/cli-v4.32/aws_sso_util-4.32.0.tar.gz";
        #       sha256 = "sha256-Jknc88WUhRoMVe1uvy33AgXR3r1uWOJjc4Qw1HA4kOw=";
        #     };
        #     format = "pyproject";
        #     doCheck = false;
        #     propagatedBuildInputs = [
        #       # Specify dependencies
        #       pkgs.python311Packages.poetry-core
        #       pkgs.python311Packages.boto
        #       pkgs.python311Packages.boto3
        #       (
        #         buildPythonPackage rec {
        #           pname = "aws-error-util";
        #           version = "2.7.0";
        #           format = "pyproject";
        #           doCheck = false;
        #           src = fetchurl {
        #             url = "https://github.com/benkehoe/aws-error-utils/releases/download/v2.7/aws_error_utils-2.7.0.tar.gz";
        #             sha256 = "sha256-BxB68qLCZwbNlSW3/77UPy0HtQ0n45+ekVbBGy6ZPJc=";
        #           };
        #           propagatedBuildInputs = [
        #             pkgs.python311Packages.poetry-core
        #             pkgs.python311Packages.pyyaml
        #             (
        #               buildPythonPackage rec {
        #                 pname = "aws-sso-lib";
        #                 version = "1.14.0";
        #                 format = "pyproject";
        #                 doCheck = false;
        #                 src = fetchurl {
        #                   url = "https://files.pythonhosted.org/packages/3d/df/302bafc5e7182212eec091269c4731bb4469041a1db5e6c3643d089d135d/aws_sso_lib-1.14.0.tar.gz";
        #                   sha256 = "sha256-sCA6ZMy2a6ePme89DrZpr/57wyP2q5yqyX81whoDzqU=";
        #                 };
        #                 propagatedBuildInputs = [
        #                   pkgs.python311Packages.poetry-core
        #                   pkgs.python311Packages.jsonschema
        #                   pkgs.python311Packages.boto3
        #                 ];
        #               }
        #             )
        #           ];
        #         }
        #       )
        #     ];
        #   }
        # )
      ]))

      # These were used for trying to get `passmenu` to work, but it just doesn't with gnome & wayland:
      # dmenu-wayland
      (if env.isOnWayland then ydotool else xdotool)

      starship
      curl
      xclip
      wl-clipboard # TODO remove this if not on wayland
      # logkeys # Was testing whether I could log laptop buttons or not
      # chromedriver
      inputs.openvpn24.legacyPackages.${system}.openvpn_24 # Needed specifically this version for tiny.work
      inputs.devenv.packages.${system}.devenv
      awscli2
      # granted # Used for the `assume` command, for fetching AWS creds
      mprocs
      android-studio
      android-tools

      # Desktop only
      # thunderbird
      tailscale
      vscode
      firefox
      google-drive-ocamlfuse
      guake
      google-chrome
      home-manager
      discord
      zoom-us
      slack
      spotify
      vlc # For video playback
      gimp
      # ventoy # For creating bootable USBs. It's really cool, just drag and drop ISOs onto the USB and you can select which one to boot from
    ];
  };

  programs = {
    zsh.enable = true;
    gnupg.agent.enable = true;
    adb.enable = true;

    # Some programs need SUID wrappers, can be configured further or are
    # started in user sessions.
    # mtr.enable = true;
  };

  fonts.packages = with pkgs; [
    (nerdfonts.override { fonts = [ "FiraCode" ]; })
  ];

  # Enable the OpenSSH daemon:
  services.openssh = {
    enable = true;
    # These commented out settings would force public key authentication, but we don't need that for now as we're using
    # tailscale to allow access to the machine. Without logging in to tailscale, only LAN access is allowed (with a password).
    # settings.PasswordAuthentication = false;
    # settings.KbdInteractiveAuthentication = false;
  };
  # Allow OpenSSH to be accessed through the firewall:
  networking.firewall.allowedTCPPorts = [ 22 ];

  services.tailscale.enable = true;

  # Open ports in the firewall for tiny.work:
  networking.firewall.trustedInterfaces = [ "tun0" "tun" ]; # For tiny.work VPN
  networking.firewall.allowedUDPPorts = [ 443 ]; # For tiny.work VPN

  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

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
