{ env, ... }:
{
  home-manager.users.${env.user} = {
    programs.lazygit = {
      enable = true;
      enableZshIntegration = true;
      # Keep in sync with files/home/.config/lazygit/config.yml
      settings = {
        git.overrideGpg = true;
        customCommands = [
          {
            key = "F";
            command = "git fetch --prune";
            context = "localBranches";
            output = "log";
          }
        ];
      };
    };
  };
}
