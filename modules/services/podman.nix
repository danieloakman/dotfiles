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
          krunkit # Podman desktop requires this
        ];
        homebrew = {
          brews = [
            "podman"
            "podman-tui"
            "podman-compose"
          ];
          casks = [ "podman-desktop" ];
        };
      };
      # Linux support is not yet implemented
    }
  );
}
