# OpenCode TUI/web agent: local llama provider + Cursor via patched cursor-proxy plugin.
{ config
, lib
, pkgs
, env
, ...
}:
let
  cfg = config.my.programs.opencode;
  llamaCppCfg = config.my.services.llama-cpp or {
    enable = false;
    port = 11343;
    models = { };
  };

  llamaSwapUrl = "http://127.0.0.1:${toString (llamaCppCfg.port + 1)}/v1";

  llamaMaxOutputTokens = context: lib.min 8192 (lib.div context 2);

  llamaModelsFromService = lib.mapAttrs
    (
      name: model:
        {
          inherit name;
          limit = {
            context = model.context-size;
            output = llamaMaxOutputTokens model.context-size;
          };
        }
        // lib.optionalAttrs (lib.hasInfix "VL" name) {
          modalities = {
            input = [
              "image"
              "text"
            ];
            output = [ "text" ];
          };
        }
    )
    llamaCppCfg.models;

  cursorAgentPackage = config.my.programs.cursor.agent.package;

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
    ++ lib.optionals cfg.providers.cursor.enable [
      cursorAgentPackage
    ]
    ++ lib.optionals cfg.providers.claude.enable [
      pkgs.claude-code
    ]
  );

  webServiceEnv =
    lib.optionals cfg.providers.cursor.enable [
      "CURSOR_AGENT_BIN=${lib.getExe cursorAgentPackage}"
      "NODE_BIN=${lib.getExe pkgs.nodejs_24}"
      "CURSOR_PROXY_SCRIPT=${cursorProxyScript}"
      "CURSOR_PROXY_QUIET=true"
    ]
    ++ lib.optionals (cfg.providers.cursor.enable || cfg.providers.claude.enable) [
      "PATH=${webServiceBinPath}:/run/current-system/sw/bin"
    ];

  opencodePlugins =
    lib.optionals cfg.providers.claude.enable [ "opencode-claude-auth@latest" ]
    ++ lib.optionals cfg.providers.cursor.enable [ "${cursorProxyPluginDir}/cursor-proxy-plugin.mjs" ];

  opencodeSettings = lib.mkMerge [
    (lib.mkIf (opencodePlugins != [ ]) {
      plugin = opencodePlugins;
    })
    (lib.mkIf cfg.providers.cursor.enable {
      model = "cursor-acp/${cfg.providers.cursor.default-model}";
      small_model = "cursor-acp/${cfg.providers.cursor.default-model}";
    })
    {
      provider = lib.mkMerge [
        (lib.mkIf (cfg.providers.llama-cpp.enable && llamaCppCfg.enable) {
          "llama.cpp" = {
            npm = "@ai-sdk/openai-compatible";
            name = "llama-swap (local)";
            options = {
              baseURL = llamaSwapUrl;
              includeUsage = true;
            };
            models = llamaModelsFromService;
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

    providers = {
      cursor = {
        enable = lib.mkEnableOption ''
          Use Cursor models in OpenCode via a patched local cursor-proxy plugin
          and a wrapped `cursor-agent` that reads `CURSOR_API_KEY`.
        '';
        default-model = lib.mkOption {
          type = lib.types.str;
          default = "auto";
          description = ''
            Default Cursor model id (without the cursor-acp/ prefix).
            `auto` matches Cursor's usual cost-efficient routing.
          '';
        };
      };

      claude.enable = lib.mkEnableOption ''
        Load `opencode-claude-auth` so Anthropic models use your Claude Code
        subscription OAuth credentials (`~/.claude/.credentials.json` on Linux).
        Run `claude login` once per host. Do not set `ANTHROPIC_API_KEY` if you
        want subscription billing. Switch models in OpenCode to use Anthropic;
        default model stays on Cursor when the cursor provider is enabled.
      '';

      llama-cpp.enable = lib.mkEnableOption ''
        Expose the local llama-swap OpenAI API in OpenCode.

        Reads `my.services.llama-cpp.port` and `my.services.llama-cpp.models`
        automatically; requires `my.services.llama-cpp.enable = true` on the host.
      '';
    };

    web = {
      enable = lib.mkEnableOption ''
        Run OpenCode as a background user service (systemd on Linux, launchd on macOS).

        Binds to 127.0.0.1 on `web.port` (default 15732),
        installs `tailscale-svc-opencode-up` / `-down`. Expose via Tailscale only
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
    {
      assertions = [
        {
          assertion = !cfg.providers.llama-cpp.enable || llamaCppCfg.enable;
          message = "my.programs.opencode.providers.llama-cpp.enable requires my.services.llama-cpp.enable on this host.";
        }
        {
          assertion = !cfg.providers.llama-cpp.enable || llamaCppCfg.models != { };
          message = "my.programs.opencode.providers.llama-cpp.enable requires at least one model in my.services.llama-cpp.models.";
        }
        {
          assertion = !cfg.providers.cursor.enable || config.my.programs.cursor.agent.enable;
          message = "my.programs.opencode.providers.cursor.enable requires my.programs.cursor.agent.enable.";
        }
        {
          assertion =
            !cfg.providers.llama-cpp.enable
            || builtins.all (model: model ? context-size && model.context-size > 0) (
              builtins.attrValues llamaCppCfg.models
            );
          message = "my.programs.opencode.providers.llama-cpp.enable requires context-size on every my.services.llama-cpp.models entry.";
        }
      ];
    }
    (lib.mkIf cfg.enable {
      home-manager.users.${env.user} = {
        home.file.".config/opencode/plugins/cursor-proxy-local".source = cursorProxyPlugin;

        home.sessionVariables = lib.mkIf cfg.providers.cursor.enable {
          CURSOR_AGENT_BIN = "${lib.getExe cursorAgentPackage}";
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
          config.EnvironmentVariables = lib.mkIf cfg.providers.cursor.enable {
            CURSOR_AGENT_BIN = lib.getExe cursorAgentPackage;
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
