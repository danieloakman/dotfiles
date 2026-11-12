# Superwhisper — voice dictation (Free: local Whisper; Pro optional).
# Linux: vendored portable release (upstream Nix flake not public yet).
# Darwin: Homebrew cask.
{ env
, config
, lib
, pkgs
, ...
}:
let
  cfg = config.my.programs.superwhisper;
  superwhisperPkg = pkgs.callPackage ./_package.nix { };
in
{
  options.my.programs.superwhisper.enable = lib.mkEnableOption ''
    Superwhisper voice-to-text. Free plan covers unlimited local Whisper dictation.
    Linux installs the portable Wayland build + a user systemd service; Darwin uses
    the Homebrew cask.
  '';

  config = lib.mkIf cfg.enable (
    env.selectPlatform {
      linux = {
        home-manager.users.${env.user} = {
          home.packages = [ superwhisperPkg ];

          systemd.user.services.superwhisper = {
            Unit = {
              Description = "Superwhisper dictation";
              After = [
                "graphical-session.target"
                "pipewire.service"
              ];
              PartOf = [ "graphical-session.target" ];
            };
            Service = {
              Type = "simple";
              ExecStart = "${lib.getExe superwhisperPkg} daemon";
              ExecStopPost = [
                "${lib.getExe superwhisperPkg} playback-restore"
                "${lib.getExe superwhisperPkg} desktop-release"
              ];
              Restart = "on-failure";
              RestartSec = 2;
              KillMode = "control-group";
              TimeoutStopSec = 15;
              UMask = "0077";
              Environment = [ "SUPERWHISPER_UPDATE_DISABLED=1" ];
            };
            Install.WantedBy = [ "graphical-session.target" ];
          };
        };
      };

      darwin = {
        homebrew.casks = [ "superwhisper" ];
      };
    }
  );
}
