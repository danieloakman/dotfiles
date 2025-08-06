# Home manager setup for 'dano' user

{ lib, pkgs, env, sops, ... }:

{
  # Turns out we need this in home-manager as well. It's not enough to just have it in the system configuration:
  nixpkgs.config.allowUnfree = true;

  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home = {
    username = env.user;
    homeDirectory = "/home/${env.user}";

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

      ".gitconfig".text = ''
        [user]
          name = Daniel (Oakman) Brown
          email = 42539848+danieloakman@users.noreply.github.com
          signingkey = 8FB975523F3FEB6113801C04368C0A3C6913D768
        [credential]
          helper = cache --timeout 604800
        [includeIf "gitdir/i:~/repos/auxilis/"]
          path = ~/.gitconfig-auxilis
        [includeIf "gitdir/i:~/repos/frogco/"]
          path = ~/.gitconfig-frogco
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
          helper = !/run/current-system/sw/bin/gh auth git-credential
        [credential "https://gist.github.com"]
          helper = 
          helper = !/run/current-system/sw/bin/gh auth git-credential
      '';

      # ".gitconfig-auxilis".text = ''
      #   [user]
      #     name = daniel.oakman
      #     email = daniel.oakman@auxilis.com.au
      #     # signingkey = ""
      #   [commit]
      #     gpgsign = false
      # '';

      # ".gitconfig-frogco".text = ''
      #   [user]
      #     name = Daniel (Oakman) Brown
      #     email = d.oakman@frogco.live
      #     signingkey = ~/.ssh/frogco.pub
      #   [gpg]
      #     format = ssh
      # '';

      ".config/lazygit/config.yml".source = ../files/home/.config/lazygit/config.yml;

      ".config/nixpkgs/config.nix".text = ''
        { ... }:
        {
          allowUnfree = true;
        }
      '';

      ".config/git/allowed_signers".source = ../files/home/.config/git/allowed_signers;

      ".config/guake/prefs".text = ''
        [general]
        compat-delete='delete-sequence'
        display-n=0
        display-tab-names=0
        gtk-use-system-default-theme=true
        hide-tabs-if-one-tab=false
        history-size=1000
        load-guake-yml=true
        max-tab-name-length=100
        mouse-display=true
        open-tab-cwd=true
        prompt-on-quit=true
        quick-open-command-line='gedit %(file_path)s'
        restore-tabs-notify=true
        restore-tabs-startup=false
        save-tabs-when-changed=true
        schema-version='3.9.0'
        scroll-keystroke=true
        start-at-login=true
        use-default-font=true
        use-popup=true
        use-scrollbar=true
        use-trayicon=true
        window-halignment=0
        window-height=50
        window-losefocus=false
        window-refocus=false
        window-tabbar=false
        window-width=100

        [keybindings/global]
        show-hide='<Primary>grave'

        [keybindings/local]
        close-tab='disabled'
        close-terminal='<Primary><Shift>w'
        split-tab-horizontal='<Shift><Alt>underscore'
        split-tab-vertical='<Shift><Alt>plus'

        [style/background]
        transparency=75

        [style/font]
        allow-bold=true
        palette='#000000000000:#cccc00000000:#4e4e9a9a0606:#c4c4a0a00000:#34346565a4a4:#757550507b7b:#060698209a9a:#d3d3d7d7cfcf:#555557575353:#efef29292929:#8a8ae2e23434:#fcfce9e94f4f:#72729f9fcfcf:#adad7f7fa8a8:#3434e2e2e2e2:#eeeeeeeeecec:#ffffffffffff:#000000000000'
        palette-name='Tango'
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

        # Create ~/bin if it doesn't exist
        if [ ! -d "$HOME/bin" ]; then
          mkdir "$HOME/bin"
        fi

        symlink $HOME/gdrive/Music $HOME/Music/gdrive
        symlink $HOME/Sync/music $HOME/Music/Sync
        symlink /run/current-system/sw/bin/google-chrome-stable $HOME/bin/google-chrome

        # Copy the ssh config file to the correct location
        cp $HOME/repos/personal/dotfiles/files/home/.ssh/config $HOME/.ssh/config
      '';

      # TODO: maybe move this to a dotfile or something
      # loadGuakePreferences = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      #   ${pkgs.guake}/bin/guake --restore-preferences ~/.config/guake/prefs
      # '';
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
      # TODO: Maybe move system level pass to home-manager, and we wouldn't need to do this
      PASSWORD_STORE_DIR = "/home/${env.user}/.local/share/password-store";
      # This is how `nh` is able to find the flake for this host's configuration.
      NH_FLAKE = "/home/${env.user}/repos/personal/dotfiles";
      GRANTED_ALIAS_CONFIGURED = "true";
      DOTFILES_DIR = "/home/${env.user}/repos/personal/dotfiles";
    };

    sessionPath = [ "/usr/local/bin" "$HOME/bin" ];
  };

  gtk = {
    enable = true;
  };

  # TODO: store Private internet access config in sops and load here somewhere

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

      # git = {
      #   enable = true;
      #   userName = "Daniel Brown";
      #   userEmail = "42539848+danieloakman@users.noreply.github.com";
      #   signing = {
      #     gpgPath = "gpg";
      #     key = "8FB975523F3FEB6113801C04368C0A3C6913D768";
      #     signByDefault = true;
      #   };
      #   extraConfig = {
      #     credential = {
      #       helper = "cache --timeout 604800";
      #     };
      #     init = {
      #       defaultBranch = "main";
      #     };
      #     pull = {
      #       ff = true;
      #     };
      #     core = {
      #       editor = "nano";
      #     };
      #     http = {
      #       postbuffer = "524288000"; 
      #     };
      #     "gpg \"ssh\"".allowedSignersFile = "~/.config/git/allowed_signers";
      #   };
      # };
    };

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

    starship = {
      enable = true;
      enableZshIntegration = true;
    };

    direnv = {
      enable = true;
      enableZshIntegration = true; # see note on other shells below
      nix-direnv.enable = true;
    };

    lf = {
      enable = true;
      keybindings = {
        "D" = "delete";
        "~" = "cd ~";
      };
      # See https://github.com/gokcehan/lf/blob/master/doc.md#options
      settings = {
        hidden = true;
        info = [ "size" "time" ];
      };
    };

    granted = {
      enable = true;
      enableZshIntegration = true;
    };
  };

  services = {
    git-sync = {
      enable = true;
      repositories = {
        "password-store" = {
          interval = 60;
          path = "/home/${env.user}/.local/share/password-store";
          uri = sops.secrets.password_store_git_url.path;
        };
      };
    };

    gpg-agent = {
      enable = true;
      enableZshIntegration = true;
      defaultCacheTtl = 604800; # 1 week
      maxCacheTtl = 604800;
      # pinentryPackage = pkgs.pinentry;
    };

    # Add gnome-keyring to handle auto gpg password entry, amongst other things:
    gnome-keyring = {
      enable = true;
      components = [ "pkcs11" "secrets" "ssh" ];
    };
  };

  # TODO: Still doesn't work, for some reason:
  # xdg = {
  #   enable = true;
  #   desktopEntries = {
  #     "org.${env.user}.move-mouse.desktop" = {
  #       name = "Move Mouse";
  #       comment = "Move the mouse to prevent auto suspension";
  #       exec = "move-mouse";
  #       type = "Application";
  #       terminal = true;
  #       categories = [ "Utility" ];
  #       # startupNotify = "false";
  #     };
  #   };
  #   # configFile = {
  #   #   "test123/a".text = ''
  #   #     something
  #   #   '';
  #   # };
  # };
}
