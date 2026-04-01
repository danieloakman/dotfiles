{ lib, env, config, ... }: {
  options.my.ai = {
    rootContext = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Context to add to every AI prompt, i.e. the CLAUDE.md/AGENTS.md files";
    };
    skills = lib.mkOption {
      type = lib.types.attrsOf (lib.types.oneOf [ lib.types.path lib.types.str ]);
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
        # Cursor uses a list of rules defined in the .cursor/rules directory. So for now we're just adding a global rule. Cursor may not even support reading rules from files like this... Maybe remove in the future.
        ".cursor/rules/global.md".text = config.my.ai.rootContext;
      };
      # At the moment, cursor supports finding skills in the .claude/skills directory, as do many other agents.
      # If for some reason in the future they don't we could probably just run an activate block that symlinks from claude/skills to whatever other directory we want to use also.
      programs.claude-code.skills = config.my.ai.skills;
    };
  };
}
