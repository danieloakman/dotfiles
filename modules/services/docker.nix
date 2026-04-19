{ env, pkgs, lib, config, ... }: {
  options.my.services.docker.enable = lib.mkEnableOption "Enable the Docker service and necessary packages like lazydocker.";
  config = lib.mkIf config.my.services.docker.enable (env.selectPlatform {
    darwin = {
      homebrew = {
        brews = [ "lazydocker" ];
        casks = [ "docker-desktop" ];
      };
    };

    linux = {
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
    };
  });
}
