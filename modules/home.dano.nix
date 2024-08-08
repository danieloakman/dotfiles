# Home manager setup for 'dano' user

{ lib, pkgs, env, ... }:

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

      # # It is sometimes useful to fine-tune packages, for example, by applying
      # # overrides. You can do that directly here, just don't forget the
      # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
      # # fonts?
      # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

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
      pkgs.passff-host
      pkgs.sxhkd
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
      ".mozilla/native-messaging-hosts/passff.json".source = "${pkgs.passff-host}/share/passff-host/passff.json";

      ".gitconfig".text = ''
        [user]
          name = Daniel Oakman
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

      ".gitconfig-auxilis".text = ''
        [user]
          name = daniel.oakman
          email = daniel.oakman@auxilis.com.au
          # signingkey = "" # TODO: create auxilis gpg key or some other way to verify commits on bitbucket
        [commit]
          gpgsign = false
      '';

      ".gitconfig-frogco".text = ''
        [user]
          name = Daniel Oakman
          email = d.oakman@frogco.live
          signingkey = ~/.ssh/frogco.pub
        [gpg]
          format = ssh
      '';

      ".config/lazygit/config.yml".source = "../files/home/.config/lazygit/config.yml";

      ".config/nixpkgs/config.nix".text = ''
        { ... }:
        {
          allowUnfree = true;
        }
      '';

      ".ssh/config".source = "../files/home/.ssh/config";

      ".config/git/allowed_signers".source = "../files/home/.config/git/allowed_signers";

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

      ".config/rclone/rclone.conf" = {
        # TODO: this should just copy instead of symlink. So move it to a createDotFile function in activation or something.
        enable = false;
        text = ''
          [gdrive]
          type = drive
          client_id = 336312788532-rr6rslp7tjcmou515a2tfruq5c6sv0fc.apps.googleusercontent.com
          client_secret = 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
          scope = drive
          token = {"access_token":"ya29.a0Ad52N39DDXHjRTDnUXORTMDJerdD0lvvU-WkYGzG9SDnaSzQhw8rldIGeP6jNDrOsN01--GJekXRcxQJL4an2IFYZk5RB9_G7kolSr64gTuWHTn8Sdgjnai-RyrM-nWPzOjEdBVV5SSS4bZsXtiW-HnadFp5ZOm75vgjaCgYKAaMSARISFQHGX2Mie4EUQx1A7DuatQsw9ZUGxQ0171","token_type":"Bearer","refresh_token":"1//0gkjL-XAaTFyMCgYIARAAGBASNgF-L9Ir4tlol43QRU_LXz0v8E5a2QRd9zcnCUakv6G2SCKOSdMGyxsMM5s4GMFazWvv140WFw","expiry":"2024-04-02T11:15:25.372792772+11:00"}
          team_drive = 
          skip_gdocs = true
        '';
      };
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
        symlink /run/current-system/sw/bin/google-chrome-stable $HOME/bin/google-chrome
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
      FLAKE = "/home/${env.user}/repos/personal/nixos";
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
      initExtra = ''
        # Put at the bottom of ".zshrc":
        if [ -f "$HOME/repos/personal/dotfiles/.main_shell" ]; then
          source "$HOME/repos/personal/dotfiles/.main_shell"
        fi
      '';
      envExtra = ''
        fpath=(/home/${env.user}/.dgranted/zsh_autocomplete/assume/ $fpath)
        fpath=(/home/${env.user}/.dgranted/zsh_autocomplete/granted/ $fpath)
      '';
      # shellAliases = {
      # };
      oh-my-zsh = {
        enable = true;
        plugins = [
          "git"
          "thefuck"
          "sudo"
          "z"
          "web-search"
          "git-auto-fetch"
        ];
        theme = "robbyrussell";
      };

      # git = {
      #   enable = true;
      #   userName = "Daniel Oakman";
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

    # Couldn't get certain binaries to install through rtx, there isn't much support for it in nix
    # rtx = {
    #   enable = true;
    #   enableZshIntegration = true;
    #   settings = {
    #     settings = {
    #       experimental = true;
    #     };
    #     tools = {
    #       # node = "latest";
    #       pnpm = "latest";
    #       # bun = "latest";
    #     };
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

    starship = {
      enable = true;
      enableZshIntegration = true;
    };

    # TODO enable firefox
    # firefox = {
    #   enable = true;
    # };

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
  };

  services = {
    git-sync = {
      enable = true;
      repositories = {
        "password-store" = {
          interval = 60;
          path = "/home/${env.user}/.local/share/password-store";
          uri = "git@github.com:danieloakman/pwd-store.git";
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

    gnome-keyring.enable = true;

    # TODO use xremap or some cross wayland xorg key mapping/remapping tool
    # Enable sxhkd daemon for keybindings:
    # sxhkd = {
    #   enable = true;
    #   keybindings."ctrl + q" = "zsh -c 'passmenu'";
    # };
  };

  # TODO: look into why this doesn't do anything
  # xdg.desktopEntries = {
  #   "org.${env.user}.move-mouse.desktop" = {
  #     name = "Move Mouse";
  #     comment = "Move the mouse to prevent auto suspension";
  #     exec = "/user/local/bin/move-mouse";
  #     type = "Application";
  #     terminal = true;
  #     categories = [ "Utility" ];
  #     # startupNotify = "false";
  #   };
  # };
}
