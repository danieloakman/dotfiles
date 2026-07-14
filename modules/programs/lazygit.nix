{ env, ... }:
{
  home-manager.users.${env.user} = {
    programs.lazygit = {
      enable = true;
      enableZshIntegration = true;
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
