{ env, inputs, system, lib, config, ... }: {
  options.my = {
    programs.guake.enable = lib.mkEnableOption "Enable the Guake terminal emulator";
  };

  config = lib.mkIf config.my.programs.guake.enable ({
    environment.systemPackages = [
      inputs.guake.legacyPackages.${system}.guake
    ];

    home-manager.users.${env.user}.programs.guake = {
      home.file.".config/guake/prefs".text = ''
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

      # TODO: maybe move this to a dotfile or something
      # activation = {
      #   loadGuakePreferences = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      #     ${pkgs.guake}/bin/guake --restore-preferences ~/.config/guake/prefs
      #   '';
      # };
    };
  });
}
