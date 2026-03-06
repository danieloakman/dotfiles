{ env, config, ... }: {
  home-manager.users.${env.user} = {
    programs = {
      zsh = {
        enable = true;
        autosuggestion.enable = true;
        enableCompletion = true;
        syntaxHighlighting.enable = true;
        initContent = ''
          # Put at the bottom of ".zshrc":
          if [ -f "$HOME/repos/personal/dotfiles/files/home/.shell_scripts/.main_shell" ]; then
            source "$HOME/repos/personal/dotfiles/files/home/.shell_scripts/.main_shell"
          fi

          # This enables included pass extensions in the password store itself (/.extension dir). For some reason this has to go here since putting it in the `sessionVariables` env var doesn't work.
          export PASSWORD_STORE_ENABLE_EXTENSIONS="true"
          export PASSWORD_STORE_DIR="$HOME/repos/personal/pwd-store"
          if [ -z "$GOOGLE_WORKSPACE_CLI_CLIENT_ID" ]; then 
            export GOOGLE_WORKSPACE_CLI_CLIENT_ID="$(cat ${config.sops.secrets.google_client_id.path})"
          fi
          if [ -z "$GOOGLE_WORKSPACE_CLI_CLIENT_SECRET" ]; then
            export GOOGLE_WORKSPACE_CLI_CLIENT_SECRET="$(cat ${config.sops.secrets.google_client_secret.path})"
          fi
          # Just straight up copy the file to `.config`:
          mkdir -p $HOME/.config/gws
          cp ${config.sops.secrets."gcloud_credentials.json".path} $HOME/.config/gws/client_secret.json
          if [ -z $GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE ]; then
            export GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE="$HOME/.config/gws/client_secret.json"
          fi
          if [ -z "$CURSOR_API_KEY" ]; then
            export CURSOR_API_KEY="$(cat ${config.sops.secrets.cursor_api_key.path})"
          fi
          if [ -z "$GH_TOKEN" ]; then
            export GH_TOKEN="$(cat ${config.sops.secrets.main_gh_token.path})"
          fi
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
}
