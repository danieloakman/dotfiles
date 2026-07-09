# Provider-agnostic AI agent sandboxes via agent-sandbox.nix (bubblewrap / macOS seatbelt).
# https://github.com/archie-judd/agent-sandbox.nix
{ config
, lib
, pkgs
, env
, inputs
, ...
}:
let
  agentsCfg = config.my.programs.agents;
  cfg = config.my.programs.agents.sandbox;

  sbx = inputs.agent-sandbox.lib.${pkgs.stdenv.hostPlatform.system};

  hasCursorApiKeyLinux =
    env.platform == "linux" && builtins.hasAttr "cursor_api_key" (config.sops.secrets or { });

  cursorApiKeyPath =
    if hasCursorApiKeyLinux then config.sops.secrets.cursor_api_key.path else null;

  githubDomains = {
    "github.com" = [
      "GET"
      "HEAD"
      "POST"
      "PUT"
      "PATCH"
      "DELETE"
    ];
    "api.github.com" = [
      "GET"
      "HEAD"
      "POST"
      "PUT"
      "PATCH"
      "DELETE"
    ];
    "raw.githubusercontent.com" = [
      "GET"
      "HEAD"
    ];
    "objects.githubusercontent.com" = [
      "GET"
      "HEAD"
    ];
  };

  claudeDomains = {
    "anthropic.com" = "*";
    "claude.com" = "*";
  };

  cursorDomains = {
    "cursor.com" = "*";
    "cursor.sh" = "*";
    "api2.cursor.sh" = "*";
    "api3.cursor.sh" = "*";
  };

  # agent-sandbox masks $HOME; bind HM-managed git identity read-only at runtime.
  sharedRoFiles =
    [
      "$HOME/.gitconfig"
      "$HOME/.gitconfig-fsai"
      "$HOME/.config/git/allowed_signers"
    ]
    ++ lib.optional (cursorApiKeyPath != null) cursorApiKeyPath;

  mkAgentSandbox =
    {
      pkg,
      binName,
      outName,
      allowedPackages ? [ ],
      rwDirs ? [ ],
      rwFiles ? [ ],
      roDirs ? [ ],
      roFiles ? [ ],
      env ? { },
      allowedDomains ? { },
    }:
    sbx.mkSandbox {
      inherit
        pkg
        binName
        outName
        rwDirs
        rwFiles
        roDirs
        env
        ;
      allowedPackages = sbx.commonTools ++ cfg.extraAllowedPackages ++ allowedPackages;
      roFiles = sharedRoFiles ++ roFiles;
      allowedDomains = githubDomains // allowedDomains // cfg.extraAllowedDomains;
    };

  cursorAgentPkg = pkgs.writeShellScriptBin "cursor-agent" (
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

  claudeSandboxed =
    mkAgentSandbox {
      pkg = pkgs.claude-code;
      binName = "claude";
      outName = "claude-sandboxed";
      rwDirs = [ "$HOME/.claude" ];
      env = {
        CLAUDE_CODE_OAUTH_TOKEN = "$CLAUDE_CODE_OAUTH_TOKEN";
        CLAUDE_CONFIG_DIR = "$HOME/.claude";
        GITHUB_TOKEN = "$GITHUB_TOKEN";
      };
      allowedDomains = claudeDomains;
    };

  cursorSandboxed =
    mkAgentSandbox {
      pkg = cursorAgentPkg;
      binName = "cursor-agent";
      outName = "cursor-agent-sandboxed";
      rwDirs = [
        "$HOME/.cursor"
        "$HOME/.config/cursor"
      ];
      env = {
        CURSOR_API_KEY = "$CURSOR_API_KEY";
      };
      allowedDomains = cursorDomains;
    };
in
{
  options.my.programs.agents.sandbox = {
    enable = lib.mkEnableOption ''
      Wrap enabled AI agent CLIs with agent-sandbox.nix.

      Sandboxed binaries are installed as `*-sandboxed` so the unsandboxed
      originals stay on PATH. Run from a project directory; only that tree (plus
      declared agent config dirs) is writable. Use YOLO flags only against the
      sandboxed entrypoints.
    '';

    agents = {
      claude = {
        enable = lib.mkEnableOption "Install a sandboxed `claude-sandboxed` binary.";
      };
      cursor = {
        enable = lib.mkEnableOption "Install a sandboxed `cursor-agent-sandboxed` binary.";
      };
    };

    extraAllowedPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [
        pkgs.nodejs_24
        pkgs.gh
      ];
      description = "Extra packages exposed on the sandbox PATH for all wrapped agents.";
    };

    extraAllowedDomains = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = ''
        Additional `allowedDomains` entries merged into every sandbox
        (agent-sandbox.nix format: domain → "*" or HTTP methods list).
      '';
    };
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !cfg.enable || agentsCfg.enable;
          message = "my.programs.agents.sandbox.enable requires my.programs.agents.enable.";
        }
        {
          assertion = !cfg.enable || !cfg.agents.cursor.enable || env.platform == "darwin" || hasCursorApiKeyLinux;
          message = "my.programs.agents.sandbox.agents.cursor.enable on Linux requires the cursor_api_key sops secret.";
        }
      ];
    }
    {
      my.programs.agents.sandbox.agents.claude.enable = lib.mkDefault config.my.programs.claude-code.enable;
      my.programs.agents.sandbox.agents.cursor.enable = lib.mkDefault (
        config.my.programs.opencode.enable or false
        && lib.attrByPath [ "my" "programs" "opencode" "providers" "cursor" "enable" ] false config
      );
    }
    (lib.mkIf (agentsCfg.enable && cfg.enable) {
      home-manager.users.${env.user} = {
        home.packages = lib.optional cfg.agents.claude.enable claudeSandboxed
          ++ lib.optional cfg.agents.cursor.enable cursorSandboxed;
      };
    })
  ];
}
