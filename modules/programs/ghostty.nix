{ env, pkgs, lib, config, ... }:
let
  cfg = config.my.programs.ghostty;
in
{
  options.my.programs.ghostty.enable = lib.mkEnableOption "Enable the Ghostty terminal emulator";

  config = lib.mkIf cfg.enable (env.selectPlatform {
    any = {
      home-manager.users.${env.user} = {
        home.file.".config/ghostty/config".text = ''
          background-opacity = 0.6
          background-blur = true

          # Enabling both cmd and alt for the quake style terminal because both have caveats
          keybind = global:alt+grave_accent=toggle_quick_terminal
          keybind = global:cmd+grave_accent=toggle_quick_terminal
          keybind = "alt+shift+]=new_split:right"
          keybind = "alt+shift+[=new_split:down"
        '';
      };
    };
    linux = {
      environment.systemPackages = with pkgs; [
        ghostty
      ];
    };
    darwin = {
      homebrew.casks = [ "ghostty" ];
    };
  });
}
