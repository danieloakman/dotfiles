# OpenCode TUI/web agent: local llama/mlx providers + Cursor via patched cursor-proxy plugin.
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
  mlxLmCfg = config.my.services.mlx-lm or {
    enable = false;
    port = 11345;
    models = { };
  };

  llamaSwapUrl = "http://127.0.0.1:${toString (llamaCppCfg.port + 1)}/v1";
  mlxUrl = "http://127.0.0.1:${toString mlxLmCfg.port}/v1";

  llamaMaxOutputTokens = context: lib.min 8192 (lib.div context 2);

  modelDisplayName = name: model:
    if (model.display-name or "") != "" then model.display-name
    else
      lib.last (
        lib.splitString "/" (
          if model.path != null then toString model.path
          else if model.repo != null then model.repo
          else name
        )
      );

  # mlx_lm.server expects a local directory or Hugging Face id in the request body.
  mlxServerModelId = name: model:
    if model.path != null then toString model.path
    else if model.repo != null then model.repo
    else name;

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

  mlxModelsFromService = lib.mapAttrs
    (
      name: model:
        let
          repo = model.repo or null;
          path = model.path or null;
          vlHaystack = lib.concatStringsSep " " (
            [ name ]
            ++ lib.optional (repo != null) repo
            ++ lib.optional (path != null) path
          );
        in
        {
          name = modelDisplayName name model;
          # Short OpenCode key stays `name`; `id` is what mlx_lm.server loads.
          id = mlxServerModelId name model;
          limit = {
            context = model.context-size;
            output = llamaMaxOutputTokens model.context-size;
          };
        }
        // lib.optionalAttrs (lib.hasInfix "VL" vlHaystack) {
          modalities = {
            input = [
              "image"
              "text"
            ];
            output = [ "text" ];
          };
        }
    )
    mlxLmCfg.models;

  mlxDefaultModelId =
    let
      marked = lib.attrNames (lib.filterAttrs (_: model: model.default or false) mlxLmCfg.models);
      ids = lib.attrNames mlxLmCfg.models;
    in
    if marked != [ ] then lib.head marked
    else if builtins.length ids == 1 then lib.head ids
    else null;

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
    (lib.mkIf
      (
        cfg.providers.mlx.enable
        && mlxLmCfg.enable
        && mlxDefaultModelId != null
        && !cfg.providers.cursor.enable
      )
      {
        model = "mlx/${mlxDefaultModelId}";
        small_model = "mlx/${mlxDefaultModelId}";
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
        (lib.mkIf (cfg.providers.mlx.enable && mlxLmCfg.enable) {
          mlx = {
            npm = "@ai-sdk/openai-compatible";
            name = "MLX (local)";
            options = {
              baseURL = mlxUrl;
              apiKey = "none";
              includeUsage = true;
            };
            models = mlxModelsFromService;
          };
        })
      ];
    }
  ];

in
{
  options.my.programs.opencode = {
    enable = lib.mkEnableOption "Enable OpenCode (TUI, web, Cursor/llama/mlx providers)";

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
        automatically; requires `my.services.llama-cpp.enable = true` on this host.
      '';

      mlx.enable = lib.mkEnableOption ''
        Expose the local mlx-lm OpenAI API in OpenCode.

        Reads `my.services.mlx-lm.port` and `my.services.mlx-lm.models`
        automatically; requires `my.services.mlx-lm.enable = true` on this host.
        Each model may set `path` (local MLX dir), `repo` (Hugging Face id), or
        use the attribute name as the Hugging Face id.
      '';
    };

    web = {
      enable = lib.mkEnableOption ''
        Run OpenCode as a background user service (systemd on Linux, launchd on macOS).

        Binds to 127.0.0.1 on `web.port` (default 15732),
        and declares `services.tailscale.serve.services.opencode` on Linux.
        Expose via Tailscale only (no HTTP basic auth). Same HTTP server and web
        UI as `opencode web`, without opening a browser.
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
        {
          assertion = !cfg.providers.mlx.enable || mlxLmCfg.enable;
          message = "my.programs.opencode.providers.mlx.enable requires my.services.mlx-lm.enable on this host.";
        }
        {
          assertion = !cfg.providers.mlx.enable || mlxLmCfg.models != { };
          message = "my.programs.opencode.providers.mlx.enable requires at least one model in my.services.mlx-lm.models.";
        }
        {
          assertion =
            !cfg.providers.mlx.enable
            || builtins.all (model: model ? context-size && model.context-size > 0) (
              builtins.attrValues mlxLmCfg.models
            );
          message = "my.programs.opencode.providers.mlx.enable requires context-size on every my.services.mlx-lm.models entry.";
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
    (lib.optionalAttrs (env.platform == "linux") (lib.mkIf (cfg.enable && cfg.web.enable) {
      # Test out if this is needed.
      # users.users.${env.user}.linger = true;
      services.tailscale.serve.services.${webTailscaleService} = {
        endpoints."tcp:443" = "http://127.0.0.1:${toString cfg.web.port}";
      };
    }))
  ];
}
