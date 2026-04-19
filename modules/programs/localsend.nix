{ config, lib, env, ... }:
let
  cfg = config.my.programs.localsend;
in
{
  options.my.programs.localsend.enable = lib.mkEnableOption "Enable and install localsend, a free alternative to airdrop.";

  config = lib.mkIf cfg.enable (env.selectPlatform {
    linux.programs.localsend = {
      enable = true;
      openFirewall = true;
    };
    darwin.homebrew.casks = [ "localsend" ];
  });
}
