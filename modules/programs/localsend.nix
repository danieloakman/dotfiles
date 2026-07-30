{ config, lib, env, pkgs, ... }:
let
  cfg = config.my.programs.localsend;
in
{
  options.my.programs.localsend.enable = lib.mkEnableOption "Enable and install localsend, a free alternative to airdrop.";

  config = lib.mkIf cfg.enable (env.selectPlatform {
    linux = {
      environment.systemPackages = with pkgs; [
        jocalsend # Rust based TUI for localsend
      ];
      programs.localsend = {
        enable = true;
        openFirewall = true;
      };
    };
    darwin.homebrew.casks = [ "localsend" ];
  });
}
