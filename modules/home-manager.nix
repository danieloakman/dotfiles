{ env
, config
, pkgs
, inputs
, ...
}:
{
  config = env.selectPlatform {
    any = {
      home-manager = {
        backupFileExtension = "bak";
        users.${env.user} = {
          programs.home-manager.enable = true;
          home = {
            username = env.user;
            homeDirectory = env.home;
            sessionVariables = {
              GRANTED_ALIAS_CONFIGURED = "true";
              DOTFILES_DIR = "${env.home}/repos/personal/dotfiles";
            };
            sessionPath = [ "$HOME/bin" ];
          };
        };
      };
    };
    linux = {
      home-manager = {
        extraSpecialArgs =
          let
            inherit (config) sops;
          in
          {
            inherit inputs env sops;
          };
        users.${env.user} = { lib, ... }: {
          nixpkgs.config.allowUnfree = true;
          gtk.enable = true;
          home = {
            # Don't bump casually; check Home Manager release notes first.
            stateVersion = "22.11";
            sessionPath = [ "/usr/local/bin" ];
            packages = [
              (pkgs.writeShellScriptBin "symlink" ''
                if [ ! -L "$2" ]; then
                  ln -s "$1" "$2"
                fi
              '')
            ];
            file = {
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
              '';
            };
          };
        };
      };
    };
    darwin = {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        users.${env.user} = {
          # Don't bump casually; check Home Manager release notes first.
          home.stateVersion = "25.05";
          # Home Manager replaces macOS login paths, so path_helper never adds
          # /opt/homebrew/bin. Mirror Linux sessionPath for Apple Silicon brew.
          home.sessionPath = [
            "/opt/homebrew/bin"
            "/opt/homebrew/sbin"
          ];
        };
      };
    };
  };
}
