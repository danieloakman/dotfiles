{ env, config, pkgs, ... }:
{
  config = env.selectPlatform {
    any = {
      programs.zsh = {
        enable = true;
      };

      home-manager.users.${env.user} = {
        programs = {
          zsh = {
            enable = true;
            autosuggestion.enable = true;
            enableCompletion = true;
            syntaxHighlighting.enable = true;
            initContent = ''
              # This enables included pass extensions in the password store itself (/.extension dir). For some reason this has to go here since putting it in the `sessionVariables` env var doesn't work.
              export PASSWORD_STORE_ENABLE_EXTENSIONS="true"
              export PASSWORD_STORE_DIR="$HOME/repos/personal/pwd-store"
              ${env.selectPlatform {
                darwin = ''
                  if [ -z "$GH_TOKEN" ]; then
                    export GH_TOKEN="$(pass api_keys/personal/github/admin)"
                  fi
                '';
                linux = ''
                  if [ -z "$GH_TOKEN" ]; then
                    export GH_TOKEN="$(cat ${config.sops.secrets.main_gh_token.path})"
                  fi
                '';
              }}
            '';
            envExtra = ''
              fpath=(${env.home}/.dgranted/zsh_autocomplete/assume/ $fpath)
              fpath=(${env.home}/.dgranted/zsh_autocomplete/granted/ $fpath)
            '';
            oh-my-zsh = {
              enable = true;
              plugins = [
                "git"
                "sudo"
                "z"
                "git-auto-fetch"
              ];
              theme = "robbyrussell";
            };
          };

          starship = {
            enable = true;
            enableZshIntegration = true;
          };

          direnv = {
            enable = true;
            enableZshIntegration = true;
            nix-direnv.enable = true;
          };

          granted = {
            enable = true;
            enableZshIntegration = true;
          };
        };
      };
    };

    linux = {
      environment = {
        shells = with pkgs; [ zsh ];
      };
    };
  };
}
