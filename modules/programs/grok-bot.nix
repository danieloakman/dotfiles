# Dotfiles glue for github:jordangarrison/grok-bot-flake.
# Grok Bot desktop agent (unfree); not in nixpkgs yet.
{ config, lib, pkgs, env, inputs, ... }:
let
  cfg = config.my.programs.grok-bot;
  grokBotPackage = inputs.grok-bot.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  options.my.programs.grok-bot = {
    enable = lib.mkEnableOption ''
      Install Grok Bot (xAI desktop agent). Package from jordangarrison/grok-bot-flake;
      Home Manager so the .desktop entry is on XDG_DATA_DIRS for sand:// / grokbot:// login.
    '';

    package = lib.mkOption {
      type = lib.types.package;
      default = grokBotPackage;
      defaultText = lib.literalExpression "inputs.grok-bot.packages.\${pkgs.stdenv.hostPlatform.system}.default";
      description = "Grok Bot package.";
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${env.user}.home.packages = [ cfg.package ];
  };
}
