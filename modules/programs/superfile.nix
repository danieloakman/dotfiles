# Prefer this over `my.programs.lf` for interactive browsing; keep lf for a
# minimalist alternative when you want it (`my.programs.lf.enable`).
{ env, config, lib, ... }:
let
  cfg = config.my.programs.superfile;

  # Matches upstream cd_on_quit shell snippet paths:
  # https://superfile.netlify.app/configure/superfile-config/
  spfLastDir = env.selectPlatform {
    linux = ''"''${XDG_STATE_HOME:-$HOME/.local/state}/superfile/lastdir"'';
    darwin = ''"$HOME/Library/Application Support/superfile/lastdir"'';
  };
in
{
  options.my.programs.superfile.enable = lib.mkEnableOption ''
    Enable and configure superfile (spf), a modern TUI file manager.

    Complements `my.programs.lf`: enable superfile for the fancy default UX;
    enable lf when you want a smaller, more spartan file manager.
  '';

  config = lib.mkIf cfg.enable {
    home-manager.users.${env.user} = {
      programs = {
        superfile = {
          enable = true;
          firstUseCheck = false;
          # Nix owns updates; skip the exit-time check.
          settings = {
            # Only override what we care about; use upstream defaults for the rest.
            ignore_missing_fields = true;
            theme = "catppuccin-mocha";
            auto_check_update = false;
            # Blank => $EDITOR (micro on workstations).
            editor = "";
            code_previewer = "bat";
            nerdfont = true;
            # Kitty (and similar) run with translucent backgrounds.
            transparent_background = true;
            cd_on_quit = true;
            default_open_file_preview = true;
            show_image_preview = true;
            show_panel_footer_info = true;
            # Size + mtime columns, matching lf's info = [size time].
            file_panel_extra_columns = 2;
            # oh-my-zsh `z`, not zoxide (see issue #45).
            zoxide_support = false;
          };
          pinnedFolders = [
            {
              name = "Home";
              location = env.home;
            }
            {
              name = "Repos";
              location = "${env.home}/repos";
            }
            {
              name = "Sync";
              location = "${env.home}/Sync";
            }
            {
              name = "gdrive";
              location = "${env.home}/gdrive";
            }
          ];
        };

        zsh.initContent = lib.mkOrder 1500 ''
          # Upstream docs use `spf`; nixpkgs installs `superfile`.
          # cd into the last panel directory when quitting via Q (cd_on_quit).
          spf() {
            export SPF_LAST_DIR=${spfLastDir}
            command superfile "$@"
            [ ! -f "$SPF_LAST_DIR" ] || {
              . "$SPF_LAST_DIR"
              rm -f -- "$SPF_LAST_DIR" > /dev/null
            }
          }
        '';
      };
    };
  };
}
