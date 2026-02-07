{ env, inputs, pkgs, lib, ... }:
let
  astalPkgs = inputs.astal.packages.${pkgs.system};
  startAgs = pkgs.writeShellScriptBin "start-ags" ''
    cd ~/repos/personal/dotfiles/modules/hyprland/ags && PASSWORD_STORE_DIR="${env.home}/repos/personal/pwd-store" bun start > /tmp/ags.log 2>&1
  '';
in
{
  services.gvfs.enable = true; # Caches network cover art for mpris with spotify usage

  environment.systemPackages = with pkgs; [
    bun # To run the ags app
    libcava # Audio visualizer cli
    startAgs

    # node2nix # To generate the node-default.nix file
  ] ++ (with astalPkgs; [
    # These astal packages have cli tools included:
    notifd
    mpris
    apps
    tray
  ]);

  home-manager.users.${env.user} = {
    # add the home manager module
    imports = [ inputs.ags.homeManagerModules.default ];

    wayland.windowManager.hyprland = {
      settings = {
        exec-once = [
          # We could maybe just call it from zsh too, and that would include all env vars we'd expect in dev to be set
          # "PASSWORD_STORE_DIR=\"${env.home}/repos/personal/pwd-store\" ags run > /tmp/ags.log 2>&1"

          # We're running it directly from here so we get access to node_modules
          # It'd be possible to package an ags derivation ourselves that installs and includes node_modules, but for now
          # it's too much work.
          "${lib.getExe startAgs}"
        ];

        bind = [
          "$mod, Q, exec, ags request toggle password-search"
        ];
      };
    };

    programs.cava.enable = true; # Audio visualizer

    programs.ags = {
      enable = true; # Still need this to include ags bin, even though the dir it creates isn't being run atm

      # symlink to ~/.config/ags
      configDir = ./.;

      # additional packages and executables to add to gjs's runtime
      extraPackages = with pkgs; (with astalPkgs; [
        hyprland
        wireplumber
        network
        notifd # Has a gvfs error when starting up
        mpris # Adds support for spotify and other mpris compatible apps
        apps # Adds an api for apps specifed as .desktop files
        tray # Adds an api for desktop tray items
        cava # Audio visualizer cli
        # TODO: include these once we know it's working
        # powerprofiles
      ]);
    };
  };
}
