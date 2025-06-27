{ env, pkgs, ... }: {
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };
  users.users.${env.user} = {
    extraGroups = [ "docker" ];
  };

  # Enable for GPU pass-through support on things like Docker conainters:
  hardware.nvidia-container-toolkit.enable = env.hasGPU;

  environment.systemPackages = with pkgs; [
    docker
    docker-compose
    docker-init
    lazydocker
  ];
}
