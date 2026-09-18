{ config, lib, env, ... }:
let
  cfg = config.my.programs.obsidian;
  vaultPath = "$HOME/Documents/obsidian-vault";
in
{
  options.my.programs.obsidian = {
    enable = lib.mkEnableOption "Enable Obsidian via the Home Manager module.";

    agent-skill.enable = lib.mkEnableOption ''
      Install the obsidian-vault skill for AI agents (via my.programs.agents).
      Points agents at ~/Documents/obsidian-vault and its AGENTS.md.
    '';
  };

  config = lib.mkMerge [
    {
      my.programs.obsidian.agent-skill.enable = lib.mkDefault (
        lib.attrByPath [ "my" "services" "syncthing" "enable" ] false config
      );
    }
    (lib.mkIf cfg.enable {
      home-manager.users.${env.user}.programs.obsidian = {
        enable = true;
        cli.enable = true;
      };
    })
    (lib.mkIf (cfg.agent-skill.enable && config.my.programs.agents.enable) {
      my.programs.agents.skills.obsidian-vault = ''
        ---
        name: obsidian-vault
        description: >-
          Read and write the personal Obsidian vault at ~/Documents/obsidian-vault.
          Use when the user mentions Obsidian, the vault, notes, daily notes, wikilinks,
          or their personal knowledge base.
        ---

        # Obsidian vault

        Vault root: `~/Documents/obsidian-vault`

        Before any vault work, Read `~/Documents/obsidian-vault/AGENTS.md` and follow it.
        That file is the source of truth for structure, conventions, and how to document work.
      '';
      my.programs.agents.sandbox.extra-rw-dirs = [ vaultPath ];
    })
  ];
}
