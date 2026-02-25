{ self, pkgs, system, env, ... }: {
  imports = [
    # ../modules/aerospace.nix
    ../modules/skhd.nix # Even though I can't get this to reliably stay running, leaving it in for now since it gives permission warnings on every login
    ../modules/zsh.nix
    ../modules/mobile-dev.nix
    ../modules/docker.nix
    ../modules/ghostty.nix
  ];

  networking.hostName = "boethiah";

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    # extraSpecialArgs = { inherit inputs system env self; };
    users.${env.user} = {
      # Let Home Manager install and manage itself.
      programs.home-manager.enable = true;

      programs.zsh.shellAliases = {
        "brew-up" = "brew update && brew upgrade --greedy";
      };

      home = {
        username = env.user;
        homeDirectory = env.home;
        stateVersion = "25.05";

        sessionVariables = {
          GRANTED_ALIAS_CONFIGURED = "true";
          DOTFILES_DIR = "${env.home}/repos/personal/dotfiles";
        };

        file = {
          ".gitconfig".text = ''
            [user]
              name = Daniel (Oakman) Brown
              email = 42539848+danieloakman@users.noreply.github.com
              signingkey = 8FB975523F3FEB6113801C04368C0A3C6913D768
            [credential]
              helper = cache --timeout 604800
            [includeIf "gitdir/i:~/repos/fsai/"]
              path = ~/.gitconfig-fsai
            [commit]
              gpgsign = true
            [init]
              defaultBranch = main
            [gpg]
              program = gpg
            [pull]
              ff = true
            [core]
              editor = nano
            [http]
              postBuffer = 524288000
            [gpg "ssh"]
              allowedSignersFile = ~/.config/git/allowed_signers
            [credential "https://github.com"]
              helper = 
              helper = !/opt/homebrew/bin/gh auth git-credential
            [credential "https://gist.github.com"]
              helper = 
              helper = !/opt/homebrew/bin/gh auth git-credential
          '';
          ".gitconfig-fsai".text = ''
            [user]
              name = Daniel (Oakman) Brown
              email = daniel.brown@futuresecure.ai
              signingkey = ~/.ssh/id_rsa.pub
            [gpg]
              format = ssh
            # [commit]
            #   gpgsign = true
          '';
          ".gnupg/gpg-agent.conf".text = ''
            default-cache-ttl 604800
            max-cache-ttl 604800
            pinentry-program /opt/homebrew/bin/pinentry-mac
          '';
          "Library/Application Support/lazygit/config.yml".source = ../files/home/.config/lazygit/config.yml;
          ".config/git/allowed_signers".source = ../files/home/.config/git/allowed_signers;
          ".ssh/config".text = ''
            Host github github.com
            IdentityFile ~/.ssh/djo-personal
            IdentitiesOnly yes
            AddKeysToAgent yes

            Host github github.com stash
            ControlPath ~/.ssh/control-%h-%p-%r
            ControlMaster auto
            ControlPersist yes
            ServerAliveInterval 30

            Host azura tail9f1d8 dinosaur-crocodile mara akatosh 100.116.141.37 100.67.189.19
            User dano
            IdentityFile ~/.ssh/djo-personal
            IdentitiesOnly yes
            AddKeysToAgent yes
            SetEnv TERM=xterm-256color
          '';
        };
      };
    };
  };

  nixpkgs = {
    config.allowUnfree = true;
    # The platform the configuration will be used on.
    hostPlatform = system;
  };

  nix = {
    # Necessary for using flakes on this system.
    settings.experimental-features = "nix-command flakes";
    # Use Determinate Nix:
    enable = false;
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
      cursor-cli

      # Golang & related tools:
      go
      gopls
      delve

      # Network utilities
      wakeonlan
      (pkgs.writeShellScriptBin "wake-akatosh" ''
        wakeonlan 4c:ed:fb:96:ee:3d
      '')
    ];
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
        _HIHideMenuBar = false;
      };
      controlcenter = {
        BatteryShowPercentage = true;
        Bluetooth = false;
      };
      dock =
        let
          hotCornerAction = {
            disabled = 0;
            missionControl = 1;
            applicationWindows = 2;
            desktop = 3;
            startScreenSaver = 4;
            disableScreenSaver = 5;
            dashboard = 6;
            putDisplayToSleep = 10;
            launchpad = 11;
            notificationCenter = 12;
            lockScreen = 13;
            quickNote = 14;
          };
        in
        {
          autohide = true;
          autohide-delay = 0.1;
          autohide-time-modifier = 0.2;
          expose-animation-duration = 0.2;
          tilesize = 50;
          showhidden = true;
          show-recents = false;
          mru-spaces = false;
          wvous-bl-corner = hotCornerAction.dashboard;
          wvous-br-corner = hotCornerAction.desktop;
          wvous-tl-corner = hotCornerAction.missionControl;
          wvous-tr-corner = hotCornerAction.notificationCenter;
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
        AutoHide = false;
        # Add margins to tiled windows:
        EnableTiledWindowMargins = true;
        # Enable drag window to edge of screen to tile left/right:
        EnableTilingByEdgeDrag = true;
        # Enable drag window to top of screen to maximize:
        EnableTopTilingByEdgeDrag = true;
        # Hide desktop icons in stage manager:
        HideDesktop = false;
        StageManagerHideWidgets = false;
        StandardHideDesktopIcons = false;
        StandardHideWidgets = false;
      };
    };

    activationScripts.postActivation.text = ''
      # Check if any settings have been changed and apply them without a logout/login cycle:
      sudo -u daniel.brown /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u

      echo "NOTE: Run 'brew-up' to upgrade Homebrew packages."
    '';
  };

  homebrew = {
    enable = true;
    onActivation = {
      # Remove all brews no longer listed here as well as their program files:
      cleanup = "zap";
    };

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
      "mas"
      "lazydocker"
      "cliclick"
      "cocoapods"
      "llmfit" # CLI tool for fitting LLMs to your data
      {
        name = "syncthing";
        restart_service = "changed";
      }
      {
        name = "mlx-lm";
        restart_service = "changed";
      }
    ];

    casks = [
      "cursor"
      "vivaldi"
      "visual-studio-code"
      # "warp"
      "zoom"
      "spotify"
      "obsidian"
      "localsend"
      "docker-desktop"
      "private-internet-access"
      "gimp"
      "tailscale-app"
    ];

    masApps = {
      Xcode = 497799835;
    };
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
    };
  };
}
