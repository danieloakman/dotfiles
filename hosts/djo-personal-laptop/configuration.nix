# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ inputs, config, pkgs, ... }:
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../modules/base.nix
    ../../modules/gnome.nix
    ../../modules/laptop-power-management.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  # Bootloader.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";
  boot.loader.grub.useOSProber = true;

  networking.hostName = "djo-personal-laptop"; # Define your hostname. `echo $HOST`

  home-manager = {
    extraSpecialArgs = { inherit inputs; };
    users = {
      dano = import ../../home.nix;
    };
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.dano = {
    isNormalUser = true;
    description = "Daniel Oakman";
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.zsh;
    # User specific packages:
    # packages = with pkgs; [ ];
  };

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
      python3
      python311Packages.pip # TODO Need a better way of handling pip, pipx and pip packages, maybe just use nix-env and install non declaratively
      python311Packages.pipx
      dmenu-wayland # TODO get passmenu working with dmenu, all that shit
      starship
      curl
      xclip
      wl-clipboard # TODO setup an alias for clip
      # logkeys # Was testing whether I could log laptop buttons or not
      chromedriver
      inputs.openvpn24.legacyPackages.${system}.openvpn_24 # Needed specifically this version for tiny.work
      awscli2
      granted # Used for the `assume` command, for fetching AWS creds

      # Desktop only
      thunderbird
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

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?
}
