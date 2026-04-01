{ lib, env, config, pkgs, ... }:
let
  cfg = config.my.ai.skills;
  # Same option types as home-manager's modules/lib/file-type.nix (source + text only).
  skillEntryModule = { name, config, ... }: {
    options = {
      text = lib.mkOption {
        type = lib.types.nullOr lib.types.lines;
        default = null;
        description = ''
          Text of the skill. If null, `source` must be set (same rules as `home.file`).
        '';
      };
      source = lib.mkOption {
        type = lib.types.path;
        description = ''
          Path of the source file or directory. If `text` is set, this defaults to a
          store file with that text (same as `home.file`).
        '';
      };
    };
    config = {
      source = lib.mkIf (config.text != null) (
        lib.mkDefault (
          pkgs.writeTextFile {
            inherit (config) text;
            executable = false;
            name = lib.strings.sanitizeDerivationName name;
          }
        )
      );
    };
  };
  aiSkillsToFiles = prefixPath: lib.mapAttrs'
    (name: value: {
      name = if value.text != null then "${prefixPath}/${name}.md" else "${prefixPath}/${name}";
      value =
        if value.text != null then
          { inherit (value) text; }
        else
          { inherit (value) source; };
    })
    cfg;
in
{
  options.my.ai = {
    rootContext = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Context to add to every AI prompt, i.e. the CLAUDE.md/AGENTS.md files";
    };
    skills = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule skillEntryModule);
      default = { };
      description = "Skills to add for all AI agents (Cursor, Claude, etc)";
    };
  };
  config = {
    home-manager.users.${env.user} = {
      home.file = {
        ".agents/AGENTS.md".text = config.my.ai.rootContext;
        ".config/agents/AGENTS.md".text = config.my.ai.rootContext;
        ".claude/CLAUDE.md".text = config.my.ai.rootContext;
        # Cursor uses a list of rules defined in the .cursor/rules directory. So for now we're just adding a global rule.
        ".cursor/rules/global.md".text = config.my.ai.rootContext;
      } // aiSkillsToFiles ".claude/skills";
      # At the moment, cursor supports finding skills in the .claude/skills directory. And having the below files as well causes duplicate skills to show up in the skills list.
      # // aiSkillsToFiles ".cursor/skills"
      # // aiSkillsToFiles ".agents/skills";
    };
  };
}
