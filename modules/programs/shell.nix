{ env, pkgs, lib, ... }:
{
  home-manager.users.${env.user} = {
    home = {
      sessionVariables = {
        GDRIVE = "${env.home}/gdrive";
        AWSCREDS = "${env.home}/.aws/credentials";
        AWSCONFIG = "${env.home}/.aws/config";
      };

      file.".ssh/config".source = ../../files/home/.ssh/config;
    };

    programs.zsh = {
      shellAliases =
        {
          ll = "eza -alF --sort=modified --reverse";
          la = "eza -aF";
          l = "eza -F";
          lt = "eza . -a -T -L";
          lg = "lazygit";
          aliasg = "alias | grep";
          wanip = "curl ifconfig.me";
          lanip = "ifconfig | grep -Eo 'inet (addr:)?([0-9]*\\.){3}[0-9]*' | grep -Eo '([0-9]*\\.){3}[0-9]*' | grep -v '127.0.0.1'";
          passgl = "pass git pull";
          passgp = "pass git push";
          passgf = "pass git fetch";
          googler = "python ${env.home}/repos/other/googler/googler";
          pnpx = "pnpm exec";
          rmzerobytes = "find . -size 0 -delete";
          # Finds libraries needed by dynamically linked executables:
          nix-alien-find-libs = ''nix run "github:thiagokokada/nix-alien#nix-alien-find-libs" -- '';
          gfl = "git fetch && git pull";
          # Override oh-my-zsh git cherry-pick alias with GNU cp:
          gcp = "${pkgs.coreutils}/bin/cp";
          clock = "clockify-cli";
          gs = "ghostscript";
        }
        // (
          if env.platform == "darwin" then {
            clip = "pbcopy";
          } else {
            clip = "xclip -sel clip";
            open = "xdg-open";
            # Use like: sleep 10; alert
            alert = ''notify-send --urgency=normal -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e 's/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//')"'';
          }
        );

      initContent = lib.mkOrder 1500 ''
        # Git commit all & git push
        function gcagp() {
          git add .
          git commit -m "$1"
          git push
        }

        # Git branch, checkout & push
        function gbcp() {
          git branch "$1"
          git checkout "$1"
          git push --set-upstream origin "$1"
        }

        function zcode() {
          z "$1" && code . && cd -
        }

        function zcursor() {
          z "$1" && cursor . && cd -
        }

        # Pass create
        function passc() {
          pass generate "$1"
          pass edit "$1"
        }

        function passlg() {
          z $PASSWORD_STORE_DIR && lazygit && cd -
        }

        function passsync() {
          pass git pull && pass git push
        }

        function prev() {
          PREV=$(fc -lrn | head -n 1)
          sh -c "pet new `printf %q "$PREV"`"
        }

        function numTerminalsOpen() {
          ps a | awk '{print $2}' | grep -vi "tty*" | uniq | wc -l
        }

        # Run fastfetch/neofetch if this is the only terminal open
        if [ "$(numTerminalsOpen)" -eq 1 ]; then
          if command -v fastfetch &> /dev/null; then
            fastfetch
          elif command -v neofetch &> /dev/null; then
            neofetch
          fi
        fi
      '';
    };
  };
}
