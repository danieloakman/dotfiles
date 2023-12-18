# Base configuration for every user, i.e. the whole system.

{ inputs, config, lib, pkgs, modulesPath, ... }:
{
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Enalbe bluetooth
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
  services.xserver = {
    layout = "us";
    xkbVariant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable experimental nix features:
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

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
      pass
      # Was trying out https://github.com/NixOS/nixpkgs/issues/104249 for passmenu fix:
      # rofi-pass
      pinentry-curses
      pinentry-qt
      # rtx # Couldn't get this to work in nixos, now installing the binaries it supports through nixpkgs
      eza
      bat
      thefuck
      lazygit
      cargo
      rustup
      fzf
      neovim
      gh
      # gh-dash
      unzip
      zip
      nixpkgs-fmt # A formatter for .nix files.
      gnat13 # Provides gcc, g++, etc
      # libgcc # Unsure why this doesn't gives gcc, g++, etc as programs to use, but it don't
      gnumake
      nodejs_18
      yarn
      nodePackages_latest.pnpm
      bun
      python312
      # python312Packages.pip # TODO Need a better way of handling pip, pipx and pip packages, maybe just use nix-env and install non declaratively
      # python312Packages.pipx
      dmenu-wayland # TODO get passmenu working with dmenu, all that shit
      starship
      curl
      xclip
      wl-clipboard # TODO setup an alias for clip
      # logkeys # Was testing whether I could log laptop buttons or not
      chromedriver
      inputs.openvpn24.legacyPackages.${system}.openvpn_24 # Needed specifically this version for tiny.work
      inputs.devenv.packages.${system}.devenv
      awscli2
      granted # Used for the `assume` command, for fetching AWS creds
      # cachix # For using with `devenv`, may enable again later if I need `devenv`

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
    ];
  };

  programs = {
    zsh.enable = true;

    gnupg.agent.enable = true;
    # Some programs need SUID wrappers, can be configured further or are
    # started in user sessions.
    # mtr.enable = true;
  };

  fonts.packages = with pkgs; [
    (nerdfonts.override { fonts = [ "FiraCode" ]; })
  ];

  # List services that you want to enable:
  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  networking.firewall.trustedInterfaces = [ "tun0" "tun" ]; # For tiny.work VPN
  networking.firewall.allowedUDPPorts = [ 443 ]; # For tiny.work VPN
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;
}
