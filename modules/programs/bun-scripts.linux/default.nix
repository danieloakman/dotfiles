# Adds the co-located bun-scripts package to systemPackages.
{ pkgs, lib, config, bun2nix, ... }:
let
  bunScriptsPackage = pkgs.callPackage ./_package.nix { inherit bun2nix; };
  gmailApiSkill = ./skills/gmail-api;
in
{
  options.my.programs.bun-scripts = {
    enable = lib.mkEnableOption "Enable the bun-scripts package";

    enable-agent-skill = lib.mkEnableOption ''
      Install the gmail-api skill for AI agents (via my.programs.agents)
    '' // {
      default = true;
    };
  };

  config = lib.mkIf config.my.programs.bun-scripts.enable {
    environment.systemPackages = [ bunScriptsPackage ];

    my.programs.agents.skill-dirs.gmail-api = lib.mkIf
      (
        config.my.programs.bun-scripts.enable-agent-skill
        && config.my.programs.agents.enable
      )
      gmailApiSkill;
  };
}
