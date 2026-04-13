{ env, lib, pkgs, config, inputs, system, ... }:
let
  cursor-cli = pkgs.writeShellScriptBin "cursor-cli" ''
    CURSOR_API_KEY="$(cat ${config.sops.secrets.cursor_api_key.path})"
    ${lib.getExe pkgs.cursor-cli} --api-key "$CURSOR_API_KEY" "$@"
  '';
  code-cursor = inputs.code-cursor.legacyPackages.${system}.code-cursor;
in
{
  options = {
    programs.cursor-cli = {
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
    };
  };

  config = {
    environment.systemPackages = with pkgs; [
      cursor-cli
      code-cursor
      (writeShellScriptBin "open-cursor" ''
        # Opens the cursor editor in the current directory
        ${lib.getExe code-cursor} . &> /tmp/cursor.log &
      '')
    ];
    home-manager.users.${env.user} = {
      home.file = {
        ".cursor/mcp.json" = {
          force = true;
          text = builtins.toJSON {
            mcpServers = config.programs.cursor-cli.mcpServers;
          };
        };
      };
    };
  };
}
