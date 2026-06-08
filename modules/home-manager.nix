{ env, config, pkgs, inputs, ... }: {
  config = env.selectPlatform {
    linux = {
      home-manager = {
        # useGlobalPkgs = true;
        # useUserPackages = true;
        extraSpecialArgs = let inherit (config) sops; in { inherit inputs env sops; };
        users.${env.user} = { lib, config, ... }: {
          # import ./home.${env.user}.nix;
          # Turns out we need this in home-manager as well. It's not enough to just have it in the system configuration:
          nixpkgs.config.allowUnfree = true;

          # Home Manager needs a bit of information about you and the paths it should
          # manage.
          home = {
            username = env.user;
            homeDirectory = env.home;

            # This value determines the Home Manager release that your configuration is
            # compatible with. This helps avoid breakage when a new Home Manager release
            # introduces backwards incompatible changes.
            # You should not change this value, even if you update Home Manager. If you do
            # want to update the value, then make sure to first check the Home Manager
            # release notes.
            stateVersion = "22.11"; # Please read the comment before changing.

            # The packages option allows you to install Nix packages into your
            # environment.
            packages = [
              # # Adds the 'hello' command to your environment. It prints a friendly
              # # "Hello, world!" when run.
              # pkgs.hello

              # # You can also create simple shell scripts directly inside your
              # # configuration. For example, this adds a command 'my-hello' to your
              # # environment:
              # (pkgs.writeShellScriptBin "my-hello" ''
              #   echo "Hello, ${config.home.username}!"
              # '')

              # Check first if destination exists, if not, then create it
              (pkgs.writeShellScriptBin "symlink" ''
                  if [ ! -L "$2" ]; then
                    ln -s "$1" "$2"
                  fi
                # '')

              # Required for passff-host to work with mozilla and its extension for `pass`
              # pkgs.passff-host
            ];

            # Home Manager is pretty good at managing dotfiles. The primary way to manage
            # plain files is through 'home.file'.
            file = {
              # # Building this configuration will create a copy of 'dotfiles/screenrc' in
              # # the Nix store. Activating the configuration will then make '~/.screenrc' a
              # # symlink to the Nix store copy.
              # ".screenrc".source = dotfiles/screenrc;

              # # You can also set the file content immediately.
              # ".gradle/gradle.properties".text = ''
              #   org.gradle.console=verbose
              #   org.gradle.daemon.idletimeout=3600000
              # '';

              # Set up passff-host for firefox password management with "Pass"
              # ".mozilla/native-messaging-hosts/passff.json".source = "${pkgs.passff-host}/share/passff-host/passff.json";

              ".config/nixpkgs/config.nix".text = ''
                { ... }:
                {
                  allowUnfree = true;
                }
              '';
            };

            activation = {
              # TODO: this should be `"...".source = "...";`
              createSymlinks = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                # Create symlinks safely:
                function symlink() {
                  if [ ! -L "$2" ]; then
                    ln -s "$1" "$2"
                  fi
                }

                mkdir -p $HOME/Music/
                symlink $HOME/gdrive/Music $HOME/Music/gdrive
                symlink $HOME/Sync/music $HOME/Music/Sync
                mkdir -p $HOME/bin
                symlink /run/current-system/sw/bin/google-chrome-stable $HOME/bin/google-chrome

                # Copy the ssh config file to the correct location
                mkdir -p $HOME/.ssh
                cp $HOME/repos/personal/dotfiles/files/home/.ssh/config $HOME/.ssh/config
              '';
            };

            # You can also manage environment variables but you will have to manually
            # source
            #
            #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
            #
            # or
            #
            #  /etc/profiles/per-user/dano/etc/profile.d/hm-session-vars.sh
            #
            # if you don't want to manage your shell through Home Manager.
            sessionVariables = {
              # EDITOR = "emacs";
              # EDITOR = "nvim";
              # This is how `nh` is able to find the flake for this host's configuration.
              NH_FLAKE = "${env.home}/repos/personal/dotfiles";
              GRANTED_ALIAS_CONFIGURED = "true";
              DOTFILES_DIR = "${env.home}/repos/personal/dotfiles";
            };

            sessionPath = [ "/usr/local/bin" "$HOME/bin" ];
          };

          gtk = {
            enable = true;
            # Silence HM 26.05+ default change while stateVersion < "26.05" (keep GTK3/4 theme in sync).
            gtk4.theme = config.gtk.theme;
          };

          # TODO: store Private internet access config in sops and load here somewhere

          # Let Home Manager install and manage itself.
          programs = {
            home-manager.enable = true;

            # Some github cli extensions weren't available, so don't enalbe in home-manager for now
            # gh = {
            #   enable = true;
            #   settings = {
            #     git_protocol = "ssh";
            #   };
            #   extensions = with pkgs; [
            #     gh-dash
            #   ];
            # };
            # gh-dash.enable = true;
          };
        };
        # This is the extension for backup files when home-manager finds a file that already exists in a
        # spot that it wants to put something in. This prevents the backup files from being overwritten
        backupFileExtension = "bak";
      };
    };
    darwin = {
      # TODO: setup boethiah's home-manager configuration here.
    };
  };
}
