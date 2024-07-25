{ pkgs, env, ... }:
{
  home-manager.users.${env.user} = {
    packages = with pkgs; [
      kitty
    ];

    programs.kitty = {
      enable = true;
      # keybindings = {
      #   "alt+shift+=" = "";
      # };
      settings = {
        update_check_interval = 0;
        enabled_layouts = "splits";
      };
    };
  };
}
