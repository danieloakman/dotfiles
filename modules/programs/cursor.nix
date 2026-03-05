{ env, lib, pkgs, config, ... }:
{
  options = {
    programs.cursor-cli = {
      enable = lib.mkEnableOption "Enable Cursor";
      mcpServers = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            command = lib.mkOption { type = lib.types.str; description = "Command to run the MCP server"; };
            args = lib.mkOption { type = lib.types.listOf lib.types.str; default = [ ]; description = "Arguments to pass to the MCP server"; };
            env = lib.mkOption { type = lib.types.attrsOf lib.types.str; default = { }; description = "Environment variables to pass to the MCP server"; };
            # Also these could be added, if needed:
            # url = {};
            # headers = {};
          };
        });
        default = { };
        description = "MCP servers to enable for Cursor";
      };

      # TODO: it turns out you can just use ~/.agents/skills to store skills. So this should be refactored into another ai or agents module.
      skills = lib.mkOption {
        type = lib.types.oneOf [
          (lib.types.attrsOf lib.types.path)
          (lib.types.attrsOf lib.types.str)
        ];
        default = { };
        description = "Skills to enable for Cursor";
      };
    };
  };

  config = {
    environment.systemPackages = with pkgs; if config.programs.cursor-cli.enable then [ cursor-cli ] else [ ];
    home-manager.users.${env.user} = {
      home.file = {
        ".cursor/mcp.json" = {
          force = true;
          text = builtins.toJSON {
            mcpServers = config.programs.cursor-cli.mcpServers;
          };
        };
      } // builtins.mapAttrs
        (name: skill: {
          ".cursor/skills/${name}.md" =
            if lib.isPath skill then {
              source = skill;
            } else {
              text = skill;
            };
        })
        config.programs.cursor-cli.skills;
    };
  };
}
