{ lib, env, config, ... }:
let
  cfg = config.my.dev.ai;
  mcpServerOpts = { ... }: {
    options = {
      command = lib.mkOption {
        type = lib.types.str;
        description = "Command to run the MCP server";
      };
      args = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Arguments to pass to the MCP server";
      };
      env = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Environment variables to pass to the MCP server";
      };
    };
  };
in
{
  options.my.dev.ai = {
    enable = lib.mkEnableOption "Enable AI features and tools.";
    rootContext = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Context to add to every AI prompt, i.e. the CLAUDE.md/AGENTS.md files";
    };
    skills = lib.mkOption {
      type = lib.types.attrsOf (lib.types.oneOf [ lib.types.path lib.types.str ]);
      default = { };
      description = "Skills to add for all AI agents (Cursor, Claude, etc). Skills are defined as strings or paths to files.";
    };
    skillDirs = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      description = "Skill directories that store skills. Will be added for all agents (Cursor, Claude, etc)";
    };
    mcp = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule mcpServerOpts);
      default = { };
      description = ''
        MCP server definitions shared across tools (Cursor CLI ~/.cursor/mcp.json,
        Claude Code, Home Manager programs.mcp, etc.). Same shape as
        programs.cursor-cli.mcpServers.
      '';
    };
  };

  config = lib.mkIf cfg.enable ({
    home-manager.users.${env.user} = {
      home.file = {
        ".agents/AGENTS.md".text = cfg.rootContext;
        ".config/agents/AGENTS.md".text = cfg.rootContext;
        # Cursor uses a list of rules defined in the .cursor/rules directory. So for now we're just adding a global rule. Cursor may not even support reading rules from files like this... Maybe remove in the future.
        ".cursor/rules/global.md".text = cfg.rootContext;
        ".cursor/mcp.json" = {
          force = true;
          text = builtins.toJSON {
            mcpServers = cfg.mcp;
          };
        };
      } // lib.mapAttrs'
        (name: dir: {
          name = ".claude/skills/${name}";
          value = {
            source = dir;
            recursive = true;
          };
        })
        cfg.skillDirs;
      programs = {
        claude-code = {
          context = cfg.rootContext;
          # At the moment, cursor supports finding skills in the .claude/skills directory, as do many other agents.
          # If for some reason in the future they don't we could probably just run an activate block that symlinks from claude/skills to whatever other directory we want to use also.
          skills = cfg.skills;
          mcpServers = cfg.mcp;
        };
        mcp = {
          enable = true;
          servers = cfg.mcp;
        };
      };
    };
  });
}
