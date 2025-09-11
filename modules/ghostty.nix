{ env, pkgs, ... }:
{
  config = {
    home-manager.users.${env.user} = {
      home.file.".config/ghostty/config".text = ''
        background-opacity = 0.6
        background-blur = true

        # Enabling both cmd and alt for the quake style terminal because both have caveats
        keybind = global:alt+grave_accent=toggle_quick_terminal
        keybind = global:cmd+grave_accent=toggle_quick_terminal
        keybind = "shift+alt>=new_split:right"
        keybind = "shift+alt>-=new_split:down"
      '';
    };
  } // env.selectPlatform {
    linux = {
      environment.systemPackages = with pkgs; [
        ghostty
      ];
    };
    darwin = {
      homebrew.casks = [ "ghostty" ];
    };
  };
}
