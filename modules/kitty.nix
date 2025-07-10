# Kitty terminal config
{ pkgs, config, ... }:
{
  home-manager.users.${config.env.user} = {
    home = {
      packages = with pkgs; [
        kitty
        tdrop
      ];
    };

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
    # This could use xremap instead.
    # services.sxhkd.keybindings."super + `" = ''tdrop -ma -w -4 -y "500" -s dropdown kitty'';
  };
}
