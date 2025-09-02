{
  description = "nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager, ... }:
    let
      system = "aarch64-darwin";
      env = {
        user = "daniel.brown";
        home = "/Users/daniel.brown";
      };
      configuration = { pkgs, ... }: {
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
            nil
            raycast
            nodejs_24
            bun
            pnpm
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
          home = env.home;
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
              Bluetooth = true;
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
            variables = {
              PASSWORD_STORE_DIR = "$HOME/repos/personal/pwd-store";
            };
            # ohMyZsh = {
            #   enable = true;
            #   theme = "robbyrussell";
            # };
            # plugins = [
            #   "git"
            # ];
          };
        };

        networking.hostName = "boethiah";
      };
    in
    {
      # Build darwin flake using:
      # $ darwin-rebuild build --flake .#boethiah
      darwinConfigurations =
        let
          config = {
            inherit system;
            modules = [
              configuration
              home-manager.darwinModules.home-manager
              {
                home-manager = {
                  useGlobalPkgs = true;
                  useUserPackages = true;
                  extraSpecialArgs = { inherit inputs system env; };
                  users.${env.user} = ./modules/home.nix;
                };
              }
            ];
          };
        in
        {
          # TODO: just use one of these host names. For some reason changing the host name on mac isn't always working.
          "boethiah" = nix-darwin.lib.darwinSystem {
            inherit (config) modules system;
          };
          "MY797HJWD7" = nix-darwin.lib.darwinSystem {
            inherit (config) modules system;
          };
        };
    };
}
