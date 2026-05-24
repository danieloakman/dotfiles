# Enables steam and other game related things.
{ pkgs, lib, config, ... }:
{
  options.my.programs.games.enable = lib.mkEnableOption "Enable and include Steam, retroarch, and other game related programs and things.";

  config = lib.mkIf config.my.programs.games.enable {
    # See https://www.youtube.com/watch?v=qlfm3MEbqYA for more information on some of these settings.

    programs = {
      steam = {
        enable = true;
        remotePlay.openFirewall = true;
        localNetworkGameTransfers.openFirewall = true;
        gamescopeSession.enable = true;
      };

      # Sets up a set of optimisations for when playing games.
      gamemode.enable = true;
    };

    environment.systemPackages = with pkgs; [
      mangohud # A hud for monitoring fps, gpu usage, etc
      # lutris # Popular game manager for linux (other than steam)
      # heroic # Heroic games launcher
      # bottles # Run windows games on linux
      retroarch-free # Emulator manager including many cores already installed
    ];

    # **NOTE**: need to add these launch options to steam games:
    # `gamemoderun %command%`, `mangohud %command%, gamescope %command%`
  };
}
