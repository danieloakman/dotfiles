{
  env,
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.services.podman;
in
{
  options.my.services.podman = {
    enable = lib.mkEnableOption "Enable and install Podman and related packages/services.";
    dockerAlias = lib.mkEnableOption "Enable the alias 'docker' to point to Podman.";
  };
  config = lib.mkIf cfg.enable (
    env.selectPlatform {
      any = {
        assertions = [
          {
            assertion = !config.my.services.docker.enable;
            message = "Docker and Podman cannot be enabled at the same time.";
          }
        ];
        home-manager.users.${env.user} = {
          programs.zsh.shellAliases = lib.mkIf cfg.dockerAlias {
            docker = "podman";
          };
        };
      };
      darwin = {
        environment.systemPackages = with pkgs; [
          # Fixes Desktop startup on macOS: Podman Desktop uses the libkrun backend, which needs krunkit installed.
          krunkit
        ];
        homebrew = {
          brews = [
            "podman"
            "podman-tui"
            "podman-compose"
          ];
          # Keep Desktop installed with the CLI stack; it manages and starts the local Podman machine VM.
          casks = [ "podman-desktop" ];
        };
      };
      # Linux support is not yet implemented
    }
  );
}
