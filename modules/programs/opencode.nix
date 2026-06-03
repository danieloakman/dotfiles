# OpenCode TUI/web agent: local llama provider + Cursor via opencode-cursor-agent-proxy.
{
  config,
  lib,
  pkgs,
  env,
  ...
}:
let
  cfg = config.my.programs.opencode;

  hasCursorApiKeyLinux =
    env.platform == "linux" && builtins.hasAttr "cursor_api_key" (config.sops.secrets or { });

  cursorAgentWrapper = pkgs.writeShellScriptBin "cursor-agent" (
    env.selectPlatform {
      linux =
        if hasCursorApiKeyLinux then
          ''
            export CURSOR_API_KEY="$(cat ${config.sops.secrets.cursor_api_key.path})"
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

  opencodeSettings = lib.mkMerge [
    (lib.mkIf cfg.cursorProvider.enable {
      plugin = [ "opencode-cursor-agent-proxy" ];
    })
    {
      provider = lib.mkMerge [
        (lib.mkIf cfg.llama.enable {
          llama.options = {
            url = cfg.llama.url;
            model = cfg.llama.model;
          };
        })
      ];
    }
  ];
in
{
  options.my.programs.opencode = {
    enable = lib.mkEnableOption "Enable OpenCode (TUI, web, Cursor/llama providers)";
    cursorProvider = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Use Cursor models in OpenCode via the opencode-cursor-agent-proxy plugin
          and a wrapped `cursor-agent` that reads `CURSOR_API_KEY`.
        '';
      };
    };

    llama = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Expose local llama-swap (or compatible) OpenAI API as the llama provider.";
      };
      url = lib.mkOption {
        type = lib.types.str;
        default = "http://localhost:11343/v1";
      };
      model = lib.mkOption {
        type = lib.types.str;
        default = "DeepSeek-R1-Distill-Qwen-7B-Q6_K";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${env.user} = {
      home.packages = lib.mkIf cfg.cursorProvider.enable [ cursorAgentWrapper ];

      home.sessionVariables = lib.mkIf cfg.cursorProvider.enable {
        CURSOR_AGENT_BIN = "${lib.getExe cursorAgentWrapper}";
      };

      programs.opencode = {
        enable = true;
        context = ''
          When reporting information to me, be extremely concise and sacrifice grammar for sake of concision.
        '';
        enableMcpIntegration = true;
        settings = opencodeSettings;
      };
    };
  };
}
