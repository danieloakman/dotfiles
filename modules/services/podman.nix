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
  };
  config = lib.mkIf cfg.enable (
    env.selectPlatform {
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
