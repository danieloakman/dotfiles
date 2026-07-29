{ lib
, pkgs
, config
, env
, ...
}:
let
  cfg = config.my.programs.cursor;
  attributionJson = builtins.toJSON {
    attributeCommitsToAgent = cfg.agent.cliConfig.attribution.attributeCommitsToAgent;
    attributePRsToAgent = cfg.agent.cliConfig.attribution.attributePRsToAgent;
  };

  hasCursorApiKeyLinux =
    env.platform == "linux" && builtins.hasAttr "cursor_api_key" (config.sops.secrets or { });

  cursorApiKeyPath =
    if hasCursorApiKeyLinux then config.sops.secrets.cursor_api_key.path else null;

  agentPackage = pkgs.writeShellScriptBin "cursor-agent" (
    env.selectPlatform {
      linux =
        if hasCursorApiKeyLinux then
          ''
            export CURSOR_API_KEY="$(< ${cursorApiKeyPath})"
            exec ${lib.getExe pkgs.cursor-cli} "$@"
          ''
        else
          ''
            echo "cursor-agent: cursor_api_key sops secret is not configured on this host" >&2
            exit 1
          '';
      darwin = ''
        export CURSOR_API_KEY="$(pass api_keys/personal/cursor_ai)"
        exec ${lib.getExe pkgs.cursor-cli} "$@"
      '';
    }
  );
in
{
  options.my.programs.cursor = {
    enable = lib.mkEnableOption "Enable the Cursor code editor";

    agent = {
      enable = lib.mkEnableOption ''
        Install the wrapped `cursor-agent` CLI that injects `CURSOR_API_KEY`
        before delegating to `pkgs.cursor-cli`.
      '';

      cliConfig = {
        attribution = {
          attributeCommitsToAgent = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              When false, the Cursor CLI agent will not add "Made with Cursor"
              trailers to commits. Maps to `attribution.attributeCommitsToAgent`
              in `~/.cursor/cli-config.json`.
            '';
          };
          attributePRsToAgent = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              When false, the Cursor CLI agent will not add attribution footers
              to pull requests. Maps to `attribution.attributePRsToAgent` in
              `~/.cursor/cli-config.json`.
            '';
          };
        };
      };

      package = lib.mkOption {
        type = lib.types.package;
        readOnly = true;
        visible = false;
        description = "Wrapped cursor-agent package for use by other modules.";
      };
    };
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !cfg.agent.enable || env.platform == "darwin" || hasCursorApiKeyLinux;
          message = "my.programs.cursor.agent.enable on Linux requires the cursor_api_key sops secret.";
        }
      ];

      my.programs.cursor.agent.package = agentPackage;

      my.programs.cursor.agent.enable = lib.mkDefault (
        cfg.enable
        || (
          (config.my.programs.opencode.enable or false)
          && (config.my.programs.opencode.providers.cursor.enable or false)
        )
        || (
          (config.my.programs.agents.sandbox.enable or false)
          && (config.my.programs.agents.sandbox.agents.cursor.enable or false)
        )
      );
    }
    (lib.mkIf cfg.agent.enable {
      home-manager.users.${env.user} =
        { lib, ... }:
        {
          home.packages = [ agentPackage ];

          # Cursor's updater drops `agent` / `cursor-agent` into ~/.local/bin (ahead of
          # nix-profile) without CURSOR_API_KEY. Own those names so every switch puts
          # our wrapper back, and prepend the store bin so it still wins if Cursor
          # overwrites the symlinks between switches.
          home.sessionPath = lib.mkBefore [ "${agentPackage}/bin" ];
          home.file.".local/bin/cursor-agent" = {
            source = "${agentPackage}/bin/cursor-agent";
            force = true;
          };
          home.file.".local/bin/agent" = {
            source = "${agentPackage}/bin/cursor-agent";
            force = true;
          };

          home.activation.setCursorCliAttribution = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            $DRY_RUN_CMD mkdir -p ${env.home}/.cursor
            cfgPath=${env.home}/.cursor/cli-config.json
            attribution='${attributionJson}'
            if [ -f "$cfgPath" ]; then
              tmp=$($DRY_RUN_CMD mktemp)
              ${lib.getExe pkgs.jq} --argjson attribution "$attribution" '.attribution = $attribution' "$cfgPath" > "$tmp"
              $DRY_RUN_CMD mv "$tmp" "$cfgPath"
            else
              $DRY_RUN_CMD ${lib.getExe pkgs.jq} -n --argjson attribution "$attribution" \
                '{ attribution: $attribution, permissions: { allow: [], deny: [] }, version: 1 }' > "$cfgPath"
            fi
          '';
        };
    })
    (lib.mkIf cfg.enable (
      env.selectPlatform {
        linux = {
          environment.systemPackages = [
            pkgs.code-cursor
          ];
        };
        darwin.homebrew.casks = [
          "cursor"
          # "cursor-cli" # boethiah can't install and use this for some reason.
        ];
      }
    ))
  ];
}
