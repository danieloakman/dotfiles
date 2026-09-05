{ env, inputs, pkgs, lib, config, ... }:
let
  cfgEnabled = config.my.desktop.ui-shell == "ags";
  astalPkgs = inputs.astal.packages.${pkgs.stdenv.hostPlatform.system};
  agsStart = pkgs.writeShellScriptBin "ags-start" ''
    cd ~/repos/personal/dotfiles/modules/hyprland.linux/ags && PASSWORD_STORE_DIR="${env.home}/repos/personal/pwd-store" bun start > /tmp/ags.log 2>&1
  '';
in
{

  config = lib.mkIf cfgEnabled {
    assertions = [
      {
        assertion = config.my.desktop.hyprland.enable;
        message = "AGS requires Hyprland to be enabled";
      }
    ];

    my.desktop.hyprland = {
      blueman.enable = true;
      hyprlock.enable = true;
      hypridle.enable = true;
      sway-utils = {
        enable = true;
        notifications.enable = true;
        volume.enable = true;
        brightness.enable = true;
        caps-lock.enable = true;
        playerctl.enable = true;
      };
    };

    services.gvfs.enable = true; # Caches network cover art for mpris with spotify usage

    environment.systemPackages = with pkgs; [
      bun # To run the ags app
      libcava # Audio visualizer cli
      agsStart

      # node2nix # To generate the node-default.nix file
    ] ++ (with astalPkgs; [
      # These astal packages have cli tools included:
      notifd
      mpris
      apps
      tray
    ]);

    home-manager.users.${env.user} = { lib, ... }:
      let
        hl = import ../_lua-lib.nix { inherit lib; };
      in
      {
      # add the home manager module
      imports = [ inputs.ags.homeManagerModules.default ];

      wayland.windowManager.hyprland = {
        settings = {
          on = [
            # We're running it directly from here so we get access to node_modules
            # It'd be possible to package an ags derivation ourselves that installs and includes node_modules, but for now
            # it's too much work.
            (hl.onStart [ (lib.getExe agsStart) ])
          ];

          bind = [
            (hl.bind (hl.key "Q") (hl.exec "ags request toggle password-search"))
            # Open app launcher. TODO: use the AGS app launcher instead.
            (hl.bind (hl.key "space") (hl.exec "rofi -show combi -combi-modi \"window,drun\" -modi combi -show-icons"))
            (hl.bind (hl.key "S") (hl.exec "rofi-google-search"))
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

      xdg.desktopEntries = {
        # System management:
        shutdown = {
          name = "Shutdown";
          exec = "shutdown -P now";
          categories = [ "System" ];
          icon = "system-shutdown";
          startupNotify = true;
        };
        reboot = {
          name = "Reboot";
          exec = "reboot";
          categories = [ "System" ];
          icon = "system-reboot";
          startupNotify = true;
        };
        suspend = {
          name = "Suspend";
          exec = "systemctl suspend";
          categories = [ "System" ];
          icon = "preferences-system";
          startupNotify = true;
        };
        logout = {
          name = "Logout";
          exec = "logout";
          categories = [ "System" ];
          icon = "system-log-out";
          startupNotify = true;
        };
      };
    };
  };
}
