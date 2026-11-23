{ lib
, pkgs
, config
, env
, ...
}:
let
  cfg = config.my.programs.cursor;
  attributionJson = builtins.toJSON {
    attributeCommitsToAgent = cfg.agent.cli-config.attribution.attribute-commits-to-agent;
    attributePRsToAgent = cfg.agent.cli-config.attribution.attribute-prs-to-agent;
  };

  hasCursorApiKeyLinux =
    env.platform == "linux" && builtins.hasAttr "cursor_api_key" (config.sops.secrets or { });

  cursorApiKeyPath =
    if hasCursorApiKeyLinux then config.sops.secrets.cursor_api_key.path else null;

  # Bare CLI for interactive use (Orca / shell). Login auth only — no CURSOR_API_KEY.
  agentPackage = pkgs.cursor-cli;

  # Key-injecting wrapper for headless modules. Not installed on PATH; consumers
  # pin lib.getExe config.my.programs.cursor.agent.apiKeyPackage.
  apiKeyPackage = pkgs.writeShellScriptBin "cursor-agent" (
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

  agentBin = lib.getExe agentPackage;
in
{
  options.my.programs.cursor = {
    enable = lib.mkEnableOption "Enable the Cursor code editor";

    agent = {
      enable = lib.mkEnableOption ''
        Install the Cursor CLI (`cursor-agent` / `agent`) for interactive login
        auth. Does not inject `CURSOR_API_KEY`. Headless modules that need the
        key should use `apiKeyPackage` via its store path.
      '';

      cli-config = {
        attribution = {
          attribute-commits-to-agent = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              When false, the Cursor CLI agent will not add "Made with Cursor"
              trailers to commits. Maps to `attribution.attribute-commits-to-agent`
              in `~/.cursor/cli-config.json`.
            '';
          };
          attribute-prs-to-agent = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              When false, the Cursor CLI agent will not add attribution footers
              to pull requests. Maps to `attribution.attribute-prs-to-agent` in
              `~/.cursor/cli-config.json`.
            '';
          };
        };
      };

      package = lib.mkOption {
        type = lib.types.package;
        readOnly = true;
        visible = false;
        description = "Bare pkgs.cursor-cli (login auth) installed on PATH.";
      };

      apiKeyPackage = lib.mkOption {
        type = lib.types.package;
        readOnly = true;
        visible = false;
        description = ''
          cursor-agent wrapper that exports CURSOR_API_KEY (Linux sops /
          Darwin pass). Not on PATH — pin with lib.getExe for headless use.
        '';
      };

      hasApiKey = lib.mkOption {
        type = lib.types.bool;
        readOnly = true;
        visible = false;
        description = "Whether apiKeyPackage can resolve a key on this host.";
      };
    };
  };

  config = lib.mkMerge [
    {
      my.programs.cursor.agent.package = agentPackage;
      my.programs.cursor.agent.apiKeyPackage = apiKeyPackage;
      # Darwin uses pass at runtime; treat as available when agent is relevant.
      my.programs.cursor.agent.hasApiKey = env.platform == "darwin" || hasCursorApiKeyLinux;

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

          # Cursor's updater drops `agent` / `cursor-agent` into ~/.local/bin
          # (ahead of nix-profile). Own those names with the bare CLI so login
          # auth wins, and prepend the store bin if Cursor overwrites symlinks.
          home.sessionPath = lib.mkBefore [ "${agentPackage}/bin" ];
          home.file.".local/bin/cursor-agent" = {
            source = agentBin;
            force = true;
          };
          home.file.".local/bin/agent" = {
            source = agentBin;
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
