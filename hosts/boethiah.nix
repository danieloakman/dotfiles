{ self
, system
, env
, ...
}:
{
  my = {
    profiles.devWorkstation.enable = true;
    services = {
      # docker.enable = true;
      podman = {
        enable = true;
        dockerAlias = true;
      };
    };
    programs = {
      desktopPkgs.enable = true;
      warp.enable = true;
      # Disabled: hunk's bun2nix build fetches npm packages at build time,
      # and IT blocks the npm registry on this machine.
      hunk.enable = false;
    };
  };

  networking.hostName = "boethiah";

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "bak";
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

  # Use Determinate Nix:
  nix.enable = false;

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
            "60" = {
              enabled = false;
            };
            # Disable '^ + Option + Space' for selecting the next input source
            "61" = {
              enabled = false;
            };
            # Disable 'Cmd + Space' for Spotlight Search
            "64" = {
              enabled = false;
            };
            # Disable 'Cmd + Alt + Space' for Finder search window
            "65" = {
              enabled = false;
            };
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
    enableZshIntegration = true;
    onActivation = {
      # Remove all brews no longer listed here as well as their program files:
      cleanup = "zap";
    };

    # Prefer nixpkgs; only list Homebrew packages that need brew (missing from
    # nixpkgs, or brew services / macOS GUI integrations).
    brews = [
      "cliclick" # Not in nixpkgs
      {
        # Keep brew service management until my.services.syncthing covers Darwin.
        name = "syncthing";
        restart_service = "changed";
      }
      {
        # Brew service integration; nixpkgs has the package but not this service wiring.
        name = "mlx-lm";
        restart_service = "changed";
      }
    ];

    casks = [
      "vivaldi"
      "visual-studio-code"
      "iterm2"
      "zoom"
      "spotify" # idk why but this causes an message to pop up to delete the spotify app. But uninstalling it and reinstalling it seems to fix it.
      "private-internet-access"
      "gimp"
      "claude-code" # For Boethiah, npmjs registry is blocked. So we have to get claude-code from homebrew and not using the home-manager option
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
    };
  };
}
