# Hunk — terminal-first diff viewer for agentic changesets.
# https://github.com/modem-dev/hunk
{ env, config, lib, inputs, system, ... }:
let
  cfg = config.my.programs.hunk;
  hunkPackage = inputs.hunk.packages.${system}.default;
in
{
  options.my.programs.hunk = {
    enable = lib.mkEnableOption ''
      Hunk (modem-dev/hunk): install the terminal diff viewer and optional git/agent integrations
    '';

    enable-git-integration = lib.mkEnableOption ''
      Set hunk as the default git pager via GIT_PAGER.
      Dotfiles manage git config outside Home Manager's programs.git module.
    '' // {
      default = true;
    };

    enable-claude-integration = lib.mkEnableOption ''
      Install the hunk-review skill for AI agents (via my.programs.agents).
    '' // {
      default = true;
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      example = {
        theme = "graphite";
        mode = "auto";
        line_numbers = true;
      };
      description = "Settings written to ~/.config/hunk/config.toml.";
    };
  };

  config = lib.mkIf cfg.enable {
    my.programs.agents.skill-dirs.hunk-review = lib.mkIf
      (
        cfg.enable-claude-integration && config.my.programs.agents.enable
      ) "${hunkPackage}/skills/hunk-review";

    home-manager.users.${env.user} = {
      imports = [ inputs.hunk.homeManagerModules.default ];

      home.sessionVariables = lib.mkIf cfg.enable-git-integration {
        GIT_PAGER = "hunk pager";
      };

      programs.hunk = {
        enable = true;
        package = hunkPackage;
        inherit (cfg) settings;
        # Upstream sets programs.git.settings.core.pager; we use GIT_PAGER instead (see above).
        enableGitIntegration = false;
        # Upstream symlinks ~/.claude/skills/hunk-review; we install via my.programs.agents.skill-dirs.
        enableClaudeIntegration = false;
      };
    };
  };
}
