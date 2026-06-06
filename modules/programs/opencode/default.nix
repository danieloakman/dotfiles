# OpenCode TUI/web agent: local llama provider + Cursor via patched cursor-proxy plugin.
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
            export CURSOR_API_KEY="$(< ${config.sops.secrets.cursor_api_key.path})"
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

  # Both plugin files must live in the same store path; separate home.file entries
  # break __dirname (each file gets its own /nix/store/...-hm_* path).
  cursorProxyPlugin = pkgs.callPackage ./cursor-proxy/_package.nix { };

  cursorProxyPluginDir = "${env.home}/.config/opencode/plugins/cursor-proxy-local";
  cursorProxyScript = "${cursorProxyPlugin}/cursor-proxy.cjs";

  webHostname = "127.0.0.1";
  webTailscaleService = "opencode";

  webExtraArgs = [
    "--hostname"
    webHostname
    "--port"
    (toString cfg.web.port)
  ];

  webServiceBinPath = lib.makeBinPath (
    [
      pkgs.coreutils
      pkgs.nodejs_24
    ]
    ++ lib.optionals cfg.cursorProvider.enable [
      pkgs.cursor-cli
      cursorAgentWrapper
    ]
    ++ lib.optionals cfg.claudeProvider.enable [
      pkgs.claude-code
    ]
  );

  webServiceEnv =
    lib.optionals cfg.cursorProvider.enable [
      "CURSOR_AGENT_BIN=${lib.getExe cursorAgentWrapper}"
      "NODE_BIN=${lib.getExe pkgs.nodejs_24}"
      "CURSOR_PROXY_SCRIPT=${cursorProxyScript}"
      "CURSOR_PROXY_QUIET=true"
    ]
    ++ lib.optionals (cfg.cursorProvider.enable || cfg.claudeProvider.enable) [
      "PATH=${webServiceBinPath}:/run/current-system/sw/bin"
    ];

  opencodePlugins =
    lib.optionals cfg.claudeProvider.enable [ "opencode-claude-auth@latest" ]
    ++ lib.optionals cfg.cursorProvider.enable [ "${cursorProxyPluginDir}/cursor-proxy-plugin.mjs" ];

  opencodeSettings = lib.mkMerge [
    (lib.mkIf (opencodePlugins != [ ]) {
      plugin = opencodePlugins;
    })
    (lib.mkIf cfg.cursorProvider.enable {
      model = "cursor-acp/${cfg.cursorProvider.defaultModel}";
      small_model = "cursor-acp/${cfg.cursorProvider.defaultModel}";
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

  tailscaleServeScripts = [
    (pkgs.writeShellScriptBin "tailscale-svc-${webTailscaleService}-up" ''
      tailscale serve --service=svc:${webTailscaleService} --https=443 127.0.0.1:${toString cfg.web.port}
    '')
    (pkgs.writeShellScriptBin "tailscale-svc-${webTailscaleService}-down" ''
      tailscale serve clear svc:${webTailscaleService}
    '')
  ];
in
{
  options.my.programs.opencode = {
    enable = lib.mkEnableOption "Enable OpenCode (TUI, web, Cursor/llama providers)";
    cursorProvider = {
      enable = lib.mkEnableOption ''
        Use Cursor models in OpenCode via a patched local cursor-proxy plugin
        and a wrapped `cursor-agent` that reads `CURSOR_API_KEY`.
      '';
      defaultModel = lib.mkOption {
        type = lib.types.str;
        default = "auto";
        description = ''
          Default Cursor model id (without the cursor-acp/ prefix).
          `auto` matches Cursor's usual cost-efficient routing.
        '';
      };
    };

    claudeProvider.enable = lib.mkEnableOption ''
      Load `opencode-claude-auth` so Anthropic models use your Claude Code
      subscription OAuth credentials (`~/.claude/.credentials.json` on Linux).
      Run `claude login` once per host. Do not set `ANTHROPIC_API_KEY` if you
      want subscription billing. Switch models in OpenCode to use Anthropic;
      default model stays on Cursor when `cursorProvider` is enabled.
    '';

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

    web = {
      enable = lib.mkEnableOption ''
        Run OpenCode as a background user service (systemd on Linux, launchd on macOS).

        Binds to 127.0.0.1 on `web.port` (default 15732), enables user lingering on Linux,
        and installs `tailscale-svc-opencode-up` / `-down`. Expose via Tailscale only
        (no HTTP basic auth). Same HTTP server and web UI as `opencode web`, without opening a browser.
      '';

      port = lib.mkOption {
        type = lib.types.port;
        default = 15732;
        description = "TCP port for `opencode serve` (loopback; expose via Tailscale Serve).";
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      home-manager.users.${env.user} = {
        home.file.".config/opencode/plugins/cursor-proxy-local".source = cursorProxyPlugin;

        home.packages = lib.mkIf cfg.cursorProvider.enable [ cursorAgentWrapper ];

        home.sessionVariables = lib.mkIf cfg.cursorProvider.enable {
          CURSOR_AGENT_BIN = "${lib.getExe cursorAgentWrapper}";
          # CURSOR_PROXY_QUIET = "true";
          NODE_BIN = "${lib.getExe pkgs.nodejs_24}";
          CURSOR_PROXY_SCRIPT = cursorProxyScript;
        };

        programs.opencode = {
          enable = true;
          enableMcpIntegration = true;
          settings = opencodeSettings;
          web = lib.mkIf cfg.web.enable {
            enable = true;
            extraArgs = webExtraArgs;
          };
        };

        # HM does not set Cursor proxy env on the web unit; extend its service.
        systemd.user.services.opencode-web = lib.mkIf (cfg.web.enable && env.platform == "linux") {
          Service.Environment = webServiceEnv;
        };

        launchd.agents.opencode-web = lib.mkIf (cfg.web.enable && env.platform == "darwin") {
          config.EnvironmentVariables = lib.mkIf cfg.cursorProvider.enable {
            CURSOR_AGENT_BIN = lib.getExe cursorAgentWrapper;
            CURSOR_PROXY_QUIET = "true";
          };
        };
      };
    })
    (lib.mkIf (cfg.enable && cfg.web.enable) (
      env.selectPlatform {
        linux = {
          # Test out if this is needed.
          # users.users.${env.user}.linger = true;
          environment.systemPackages = tailscaleServeScripts;
        };
        darwin = { };
      }
    ))
  ];
}
