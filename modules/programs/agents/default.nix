{ lib, env, config, ... }:
let
  cfg = config.my.programs.agents;
  mcpServerOpts = _: {
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

  # `@~/.claude/rules/<name>.md` index for AGENTS.md / opencode context.
  rulesIndexText =
    ruleNames:
    lib.concatMapStrings (name: "@~/.claude/rules/${name}.md\n") (lib.sort lib.lessThan ruleNames);
in
{
  options.my.programs.agents = {
    enable = lib.mkEnableOption "Enable shared AI agent configuration (rules, skills, MCP).";
    rules = lib.mkOption {
      type = lib.types.attrsOf (lib.types.either lib.types.lines lib.types.path);
      default = { };
      description = ''
        Shared agent rules installed as `~/.claude/rules/<name>.md` (via Claude Code).
        AGENTS.md, OpenCode context, and `~/.cursor/rules` point at the same files.
      '';
    };
    skills = lib.mkOption {
      type = lib.types.attrsOf (lib.types.oneOf [ lib.types.path lib.types.str ]);
      default = { };
      description = "Skills to add for all AI agents (Cursor, Claude, etc). Skills are defined as strings or paths to files.";
    };
    skillDirs = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      description = "Skill directories to add for all AI agents. If a directory contains a SKILL.md it is treated as a single skill; otherwise each subdirectory is symlinked individually.";
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

  config = lib.mkIf cfg.enable {
    home-manager.users.${env.user} =
      { config, lib, ... }:
      let
        ruleNames = lib.attrNames config.programs.claude-code.rules;
        index = rulesIndexText ruleNames;
      in
      {
        home.file = {
          ".agents/AGENTS.md".text = index;
          ".config/agents/AGENTS.md".text = index;
          # Same rule files Claude uses; Cursor reads ~/.cursor/rules/.
          ".cursor/rules" = {
            source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.claude/rules";
            force = true;
          };
          ".cursor/mcp.json" = {
            force = true;
            text = builtins.toJSON {
              mcpServers = cfg.mcp;
            };
          };
        }
        // lib.concatMapAttrs
          # If the dir is a single skill (has SKILL.md), symlink it directly; otherwise
          # treat it as a collection and symlink each subdirectory individually.
          (
            name: dir:
            if builtins.pathExists "${dir}/SKILL.md" then
              {
                ".claude/skills/${name}" = {
                  source = dir;
                  recursive = true;
                };
              }
            else
              lib.mapAttrs' (skillName: _: {
                name = ".claude/skills/${skillName}";
                value = {
                  source = "${dir}/${skillName}";
                  recursive = true;
                };
              }) (lib.filterAttrs (_: type: type == "directory") (builtins.readDir dir))
          )
          cfg.skillDirs;

        programs = {
          claude-code = {
            rules = cfg.rules;
            # At the moment, cursor supports finding skills in the .claude/skills directory, as do many other agents.
            inherit (cfg) skills;
            # mcpServers requires a non-null package; Darwin uses Homebrew for the binary.
          }
          // lib.optionalAttrs (env.platform != "darwin") {
            mcpServers = cfg.mcp;
          };
          opencode = {
            context = index;
          };
          mcp = {
            enable = true;
            servers = cfg.mcp;
          };
        };
      };
  };
}
