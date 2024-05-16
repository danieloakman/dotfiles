# Base configuration for every user, i.e. the whole system.

{ inputs, pkgs, env, ... }:
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
    settings ={
      # Enable experimental nix features:
      experimental-features = [ "nix-command" "flakes" ];
      trusted-users = [ "root" "@wheel" ];
    };
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
      fastfetch
      ((if env.isOnWayland then pass-wayland else pass).withExtensions (ext: with ext; [
        pass-otp
        pass-update
        pass-checkup
        pass-audit
      ]))
      (if env.isOnWayland then pass-wayland else pass)
      # Was trying out https://github.com/NixOS/nixpkgs/issues/104249 for passmenu fix:
      # rofi-pass
      # pinentry-curses
      # pinentry-qt
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
      # rclone # Don't need anymore as it was just used for Obsidian syncing
      nixpkgs-fmt # A formatter for .nix files.
      gnat13 # Provides gcc, g++, etc
      # libgcc # Unsure why this doesn't gives gcc, g++, etc as programs to use, but it don't
      gnumake
      nurl # Generates nix fetcher urls
      dust
      nil # Nix LSP
      tldr
      gcalcli
      zbar # Can scan QR & bar codes using this
      lf # Terminal file system manager

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
      nodejs_22
      # yarn
      nodePackages_latest.pnpm
      bun

      python3
      (python3.withPackages (ps: with ps; [
        # TODO: comment out most of this in favour of using a devenv and locally installed packages instead
        pip
        # pipx
      ]))

      # These were used for trying to get `passmenu` to work, but it just doesn't with gnome & wayland:
      (if env.isOnWayland then dmenu-wayland else dmenu)
      (if env.isOnWayland then ydotool else xdotool)

      starship
      curl
      xclip
      # logkeys # Was testing whether I could log laptop buttons or not
      inputs.openvpn24.legacyPackages.${system}.openvpn_24 # Needed specifically this version for tiny.work
      inputs.devenv.packages.${system}.devenv
      awscli2
      mprocs

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
      obsidian
      # dropbox # Was trying this out for syncing with mobile. But offline sync on mobile is only available for paid users.
      # ventoy # For creating bootable USBs. It's really cool, just drag and drop ISOs onto the USB and you can select which one to boot from
      # foot # Maybe can use this for quick to load terminal that's a replacement for dmenu in gnome wayland
    ] ++ (if env.isOnWayland then [
      wl-clipboard
    ] else []);
  };

  programs = {
    zsh.enable = true;
    gnupg.agent.enable = true;
    # nix-ld = {
    #   enable = false;
    #   libraries = with pkgs; [
    #     # Add any missing dynamic libraries for unpackaged programs
    #     # here, NOT in environment.systemPackages
    #     # TODO: move stuff from auxilis FHS shell to here, probably.
    #     # TODO: put stuff in here that's needed to install playwright
    #   ];
    # };
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
  services.tailscale.enable = true;

  networking.firewall.enable = true;
  # Allow OpenSSH and other dev related ports accessible through firewall
  networking.firewall.allowedTCPPorts = [ 22 3000 3001 8000 8010 8090 5173 ];
  # Open ports in the firewall for tiny.work:
  networking.firewall.trustedInterfaces = [ "tun0" "tun" ]; # For tiny.work VPN
  networking.firewall.allowedUDPPorts = [ 443 ]; # For tiny.work VPN
  # networking.firewall.checkReversePath = false;

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
