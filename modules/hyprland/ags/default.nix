{ env, inputs, pkgs, ... }:
let
  astalPkgs = inputs.astal.packages.${pkgs.system};
in
{
  services.gvfs.enable = true; # Caches network cover art for mpris with spotify usage

  home-manager.users.${env.user} = {
    # add the home manager module
    imports = [ inputs.ags.homeManagerModules.default ];

    wayland.windowManager.hyprland = {
      settings = {
        exec-once = [
          # We could maybe just call it from zsh too, and that would include all env vars we'd expect in dev to be set
          "PASSWORD_STORE_DIR=\"/home/${env.user}/.local/share/password-store\" ags run > /tmp/ags.log 2>&1"
        ];

        bind = [
          "$mod, Q, exec, ags request \"toggle password-search\""
        ];
      };
    };

    home.packages = with astalPkgs; [
      # These astal packages have cli tools included:
      notifd
      mpris
      apps
      tray
    ];

    programs.ags = {
      enable = true;

      # symlink to ~/.config/ags
      configDir = ./.;

      # additional packages and executables to add to gjs's runtime
      extraPackages = with pkgs; [
        # fzf
      ] ++ (with astalPkgs; [
        hyprland
        wireplumber
        network
        notifd
        mpris # Adds support for spotify and other mpris compatible apps
        apps # Adds an api for apps specifed as .desktop files
        tray
        # TODO: include these once we know it's working
        # powerprofiles
      ]);
    };
  };
}
