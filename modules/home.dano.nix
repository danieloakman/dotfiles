# Home manager setup for 'dano' user

{ lib, pkgs, env, ... }:

{
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
        [includeIf "gitdir/i:~/repos/fsai/"]
          path = ~/.gitconfig-fsai
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

      ".gitconfig-fsai".text = ''
        [user]
          name = Daniel (Oakman) Brown
          email = daniel.brown@futuresecure.ai
          signingkey = ~/.ssh/fsai.pub
        [gpg]
          format = ssh
      '';

      ".config/lazygit/config.yml".source = ../files/home/.config/lazygit/config.yml;

      ".config/nixpkgs/config.nix".text = ''
        { ... }:
        {
          allowUnfree = true;
        }
      '';

      ".config/git/allowed_signers".source = ../files/home/.config/git/allowed_signers;
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
      NH_FLAKE = "${env.home}/repos/personal/dotfiles/linux";
      GRANTED_ALIAS_CONFIGURED = "true";
      DOTFILES_DIR = "${env.home}/repos/personal/dotfiles";
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
  };

  services = {
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
}
