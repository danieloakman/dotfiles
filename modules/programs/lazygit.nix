{ env, lib, ... }:
let
  lazygitSettings = lib.importYAML (builtins.readFile ../files/home/.config/lazygit/config.yml);
in
{
  home-manager.users.${env.user} = {
    programs.lazygit = {
      enable = true;
      enableZshIntegration = true;
      settings = lazygitSettings;
    };
  };
}
