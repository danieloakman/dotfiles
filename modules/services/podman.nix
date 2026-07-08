{ env
, config
, lib
, ...
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
        homebrew = {
          # krunkit must come from the slp/krun tap — the nixpkgs build omits the required
          # firmware file (KRUN_EFI.silent.fd) that only ships in the pre-built release artifacts.
          # Homebrew 6.0+ requires non-official taps to be explicitly trusted.
          taps = [
            {
              name = "slp/krun";
              trusted = true;
            }
          ];
          brews = [
            "podman"
            "podman-tui"
            "podman-compose"
            {
              name = "slp/krun/krunkit";
              trusted = true;
            }
          ];
          # Keep Desktop installed with the CLI stack; it manages and starts the local Podman machine VM.
          casks = [ "podman-desktop" ];
        };
      };
      # Linux support is not yet implemented
    }
  );
}
