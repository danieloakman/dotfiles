{ config, pkgs, ... }: {
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };
  users.users.${config.env.user} = {
    extraGroups = [ "docker" ];
  };

  # Enable for GPU pass-through support on things like Docker conainters:
  hardware.nvidia-container-toolkit.enable = config.env.hasGPU;

  environment.systemPackages = with pkgs; [
    docker
    docker-compose
    docker-init
    lazydocker
  ];
}
