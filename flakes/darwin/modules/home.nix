{ env, ... }: {
  home = {
    username = env.user;
    homeDirectory = env.home;
    stateVersion = "25.05";

    file.".gitconfig".text = ''
      [user]
        name = Daniel (Oakman) Brown
        email = 42539848+danieloakman@users.noreply.github.com
        signingkey = 8FB975523F3FEB6113801C04368C0A3C6913D768
      [credential]
        helper = cache --timeout 604800
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
  };

  # Let Home Manager install and manage itself.
  programs = {
    home-manager.enable = true;

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
      '';
      envExtra = ''
        fpath=(/home/${env.user}/.dgranted/zsh_autocomplete/assume/ $fpath)
        fpath=(/home/${env.user}/.dgranted/zsh_autocomplete/granted/ $fpath)
      '';
      shellAliases = {
        nixos-search = "nix search nixpkgs";
      };
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
      enableZshIntegration = true; # see note on other shells below
      nix-direnv.enable = true;
    };

    granted = {
      enable = true;
      enableZshIntegration = true;
    };
  };

  services = {
    gpg-agent = {
      enable = true;
      enableSshSupport = true;
      pinentry.program = "/opt/homebrew/bin/pinentry-mac";
      enableZshIntegration = true;
      defaultCacheTtl = 604800; # 1 week
      maxCacheTtl = 604800;
    };
  };
}
