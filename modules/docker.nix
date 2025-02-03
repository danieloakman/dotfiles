{ env, ... }:{
  virtualisation.docker.enable = true;
  users.users.${env.user}.extraGroups = [ "docker" ];

  # Enable for GPU pass-through support on things like Docker conainters:
  hardware.nvidia-container-toolkit.enable = true;
