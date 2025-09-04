{ self, pkgs, system, env, inputs, ... }: {
  imports = [
    # ../modules/aerospace.nix
    # ../modules/skhd.nix
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs system env self; };
    users.${env.user} = ../modules/home.nix;
  };

  nixpkgs = {
    config.allowUnfree = true;
    # The platform the configuration will be used on.
    hostPlatform = system;
  };

  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment = {
    systemPackages = with pkgs; [
      nixpkgs-fmt
      statix
      nil
      raycast
      nodejs_24
      bun
      pnpm
      pnpm-shell-completion
      pet # CLI tool for keeping a list of commands and executing them later
    ];
  };

  nix = {
    # Necessary for using flakes on this system.
    settings.experimental-features = "nix-command flakes";
    # Use Determinate Nix:
    enable = false;
  };

  users.users.${env.user} = {
    name = env.user;
    inherit (env) home;
  };

  system = {
    # Set Git commit hash for darwin-version.
    configurationRevision = self.rev or self.dirtyRev or null;

    # Used for backwards compatibility, please read the changelog before changing.
    # $ darwin-rebuild changelog
    stateVersion = 6;

    primaryUser = env.user;

    defaults = {
      NSGlobalDomain = {
        # Use F1, F2, etc. keys as standard function keys:
        "com.apple.keyboard.fnState" = true;
        AppleShowAllFiles = true;
        AppleShowAllExtensions = true;
        InitialKeyRepeat = 20;
        KeyRepeat = 3;
      };
      controlcenter = {
        BatteryShowPercentage = true;
        Bluetooth = false;
      };
      dock = {
        autohide = true;
        autohide-delay = 0.1;
        autohide-time-modifier = 0.2;
        expose-animation-duration = 0.2;
        tilesize = 50;
        showhidden = true;
        show-recents = false;
        mru-spaces = false;
      };
      CustomUserPreferences = {
        "com.apple.symbolichotkeys" = {
          AppleSymbolicHotKeys = {
            # Disable '^ + Space' for selecting the previous input source
            "60" = { enabled = false; };
            # Disable '^ + Option + Space' for selecting the next input source
            "61" = { enabled = false; };
            # Disable 'Cmd + Space' for Spotlight Search
            "64" = { enabled = false; };
            # Disable 'Cmd + Alt + Space' for Finder search window
            "65" = { enabled = false; };
          };
        };
        "com.apple.TimeMachine".DoNotOfferNewDisksForBackup = true;
        # Prevent Photos from opening automatically when devices are plugged in:
        "com.apple.ImageCapture".disableHotPlug = true;
        "com.apple.finder" = {
          ShowExternalHardDrivesOnDesktop = true;
          ShowHardDrivesOnDesktop = true;
          ShowMountedServersOnDesktop = true;
          ShowRemovableMediaOnDesktop = true;
          _FXSortFoldersFirst = true;
          # When performing a search, search the current folder by default
          FXDefaultSearchScope = "SCcf";
        };
        "com.apple.desktopservices" = {
          # Avoid creating .DS_Store files on network or USB volumes
          DSDontWriteNetworkStores = true;
          DSDontWriteUSBStores = true;
        };
      };
      WindowManager = {
        # Enable Stage Manager:
        GloballyEnabled = true;
      };
    };

    activationScripts.postActivation.text = ''
      # Check if any settings have been changed and apply them without a logout/login cycle:
      sudo -u daniel.brown /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
    '';
  };

  homebrew = {
    enable = true;

    brews = [
      "gh"
      "git"
      "eza"
      "bat"
      "lazygit"
      "pass"
      "pass-otp"
      "gemini-cli"
      "fastfetch"
      "pinentry-mac"
      "btop"
      "fzf"
      "starship"
      "dust"
      "zbar"
      "awscli"
      "mprocs"
      "entr" # Run some command when file(s) change
      {
        name = "syncthing";
        restart_service = "changed";
      }
    ];

    casks = [
      "cursor"
      "vivaldi"
      "visual-studio-code"
      "warp"
      "zoom"
    ];
  };

  programs = {
    zsh = {
      enable = true;
      enableAutosuggestions = true;
      enableFastSyntaxHighlighting = true;
      enableCompletion = true;
      variables = {
        PASSWORD_STORE_DIR = "$HOME/repos/personal/pwd-store";
        PASSWORD_STORE_ENABLE_EXTENSIONS = "true";
      };
      # shellInit = ''
      #   # Put at the bottom of ".zshrc":
      #   if [ -f "$HOME/repos/personal/dotfiles/files/home/.shell_scripts/.main_shell" ]; then
      #     source "$HOME/repos/personal/dotfiles/files/home/.shell_scripts/.main_shell"
      #   fi

      #   fpath=(/home/${env.user}/.dgranted/zsh_autocomplete/assume/ $fpath)
      #   fpath=(/home/${env.user}/.dgranted/zsh_autocomplete/granted/ $fpath)
      # '';
    };
  };

  networking.hostName = "boethiah";
}
