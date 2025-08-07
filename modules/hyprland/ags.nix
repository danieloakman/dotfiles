{ env, inputs, pkgs, ... }: {
  services.gvfs.enable = true; # Caches network cover art for mpris with spotify usage

  home-manager.users.${env.user} = {
    # add the home manager module
    imports = [ inputs.ags.homeManagerModules.default ];

    wayland.windowManager.hyprland = {
      settings = {
        exec-once = [
          "ags run > /tmp/ags.log 2>&1"
        ];
      };
    };

    programs.ags = {
      enable = true;

      # symlink to ~/.config/ags
      configDir = ./ags;

      # additional packages and executables to add to gjs's runtime
      extraPackages = with pkgs; [
        # fzf
      ] ++ (with inputs.astal.packages.${pkgs.system}; [
        hyprland
        wireplumber
        network
        notifd
        mpris # Adds support for spotify and other mpris compatible apps
        apps # Adds an api for apps specifed as .desktop files
        # TODO: include these once we know it's working
        # powerprofiles
      ]);
    };
  };
}
