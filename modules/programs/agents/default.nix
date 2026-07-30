{ lib, env, config, ... }:
let
  cfg = config.my.programs.agents;
  mcpServerOpts = _: {
    options = {
      command = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Executable for a local (stdio) MCP server.
          Mutually exclusive with `url`.
        '';
      };
      args = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Arguments to pass to `command` (stdio servers only).";
      };
      env = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Environment variables for stdio MCP servers.";
      };
      url = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          HTTP(S) endpoint for a remote MCP server.
          Mutually exclusive with `command`.
        '';
      };
      headers = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "HTTP headers for remote (`url`) MCP servers.";
      };
    };
  };

  # Emit Cursor/Claude-friendly MCP server attrs (no nulls; typed transport).
  formatMcpServer =
    server:
    if server.url != null then
      {
        type = "http";
        inherit (server) url;
      }
      // lib.optionalAttrs (server.headers != { }) { inherit (server) headers; }
    else
      {
        type = "stdio";
        inherit (server) command;
      }
      // lib.optionalAttrs (server.args != [ ]) { inherit (server) args; }
      // lib.optionalAttrs (server.env != { }) { inherit (server) env; };

  formattedMcp = lib.mapAttrs (_: formatMcpServer) cfg.mcp;

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
        Claude Code, Home Manager programs.mcp, etc.). Each server must set exactly
        one of `command` (stdio) or `url` (HTTP).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = lib.concatLists (
      lib.mapAttrsToList
        (name: server: [
          {
            assertion = (server.command != null) != (server.url != null);
            message = "my.programs.agents.mcp.${name}: exactly one of `command` or `url` must be set.";
          }
          {
            assertion = server.url == null || (server.args == [ ] && server.env == { });
            message = "my.programs.agents.mcp.${name}: `args` and `env` are only valid for stdio servers (`command`).";
          }
          {
            assertion = server.headers == { } || server.url != null;
            message = "my.programs.agents.mcp.${name}: `headers` is only valid for remote servers (`url`).";
          }
        ])
        cfg.mcp
    );

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
          ".cursor/mcp.json" = {
            force = true;
            text = builtins.toJSON {
              mcpServers = formattedMcp;
            };
          };
        }
        # Per-file symlinks (not a whole-dir symlink) so tool-specific rules can
        # sit in ~/.cursor/rules/ alongside the shared Claude rules.
        // lib.mapAttrs'
          (name: _: {
            name = ".cursor/rules/${name}.md";
            value = {
              source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.claude/rules/${name}.md";
              force = true;
            };
          })
          config.programs.claude-code.rules
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
                lib.mapAttrs'
                  (skillName: _: {
                    name = ".claude/skills/${skillName}";
                    value = {
                      source = "${dir}/${skillName}";
                      recursive = true;
                    };
                  })
                  (lib.filterAttrs (_: type: type == "directory") (builtins.readDir dir))
          )
          cfg.skillDirs;

        programs = {
          claude-code = {
            inherit (cfg) rules;
            # At the moment, cursor supports finding skills in the .claude/skills directory, as do many other agents.
            inherit (cfg) skills;
            # mcpServers requires a non-null package; Darwin uses Homebrew for the binary.
          }
          // lib.optionalAttrs (env.platform != "darwin") {
            mcpServers = formattedMcp;
          };
          opencode = {
            context = index;
          };
          mcp = {
            enable = true;
            # Pass raw options (command XOR url); HM programs.mcp validates and types them.
            servers = cfg.mcp;
          };
        };
      };
  };
}
