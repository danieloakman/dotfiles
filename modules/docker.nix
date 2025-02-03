{ env, ... }:{
  virtualisation.docker.enable = true;
  users.users.${env.user}.extraGroups = [ "docker" ];
}