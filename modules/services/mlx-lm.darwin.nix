# Homebrew mlx-lm server (OpenAI-compatible) for Apple Silicon.
# The formula is in nixpkgs too, but brew tracks MLX releases more closely
# and already supplies the binary; this module owns launchd instead of
# `brew services`.
{ config
, lib
, env
, ...
}:
let
  cfg = config.my.services.mlx-lm;
  host = "127.0.0.1";
  defaultMaxTokens = 8192;

  # What mlx_lm.server / OpenCode should put in the request `model` field.
  serverModelId = name: model:
    if model.path != null then toString model.path
    else if model.repo != null then model.repo
    else name;

  defaultModelName =
    let
      marked = lib.attrNames (lib.filterAttrs (_: model: model.default) cfg.models);
      ids = lib.attrNames cfg.models;
    in
    if marked != [ ] then lib.head marked
    else if builtins.length ids == 1 then lib.head ids
    else null;

  defaultServerModel =
    if defaultModelName == null then null
    else serverModelId defaultModelName cfg.models.${defaultModelName};

  serverArgs = [
    "--host"
    host
    "--port"
    (toString cfg.port)
    "--max-tokens"
    (toString defaultMaxTokens)
  ]
  ++ lib.optionals (defaultServerModel != null) [ "--model" defaultServerModel ]
  ++ lib.optionals cfg.trust-remote-code [ "--trust-remote-code" ]
  ++ cfg.extra-args;
in
{
  options.my.services.mlx-lm = {
    enable = lib.mkEnableOption "Enable the mlx-lm OpenAI HTTP server (launchd, Homebrew binary)";

    port = lib.mkOption {
      type = lib.types.port;
      default = 11345;
      description = "TCP port for `mlx_lm.server` (loopback).";
    };

    bin = lib.mkOption {
      type = lib.types.str;
      default = "/opt/homebrew/opt/mlx-lm/bin/mlx_lm.server";
      description = "Absolute path to `mlx_lm.server` (Homebrew keg symlink).";
    };

    trust-remote-code = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Pass `--trust-remote-code` (needed by some Hugging Face tokenizers).";
    };

    extra-args = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Extra arguments appended to `mlx_lm.server`.";
    };

    models = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          path = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = ''
              Absolute path to a local MLX model directory (weights + tokenizer +
              config), same role as `my.services.llama-cpp.models.*.path`.
              Mutually exclusive with `repo`. When set, OpenCode sends this path
              as the API model id.
            '';
            example = "/Users/me/models/Qwen3-Coder-30B-4bit";
          };
          repo = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = ''
              Hugging Face repo id for mlx_lm to download/cache. Mutually
              exclusive with `path`. If both `path` and `repo` are null, the
              attribute name is used as the repo id.
            '';
            example = "mlx-community/Qwen3-Coder-30B-A3B-Instruct-4bit";
          };
          display-name = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = ''
              Display name in OpenCode. Empty uses the last path component of the
              attr name (or of `repo` / `path` when set).
            '';
          };
          context-size = lib.mkOption {
            type = lib.types.int;
            description = ''
              Context window in tokens for OpenCode limits. Use a practical value
              for unified memory (often lower than the model's native maximum).
            '';
          };
          default = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Use this model as OpenCode's default when the mlx provider is
              enabled, and pass it as `mlx_lm.server --model` at startup.
            '';
          };
        };
      });
      default = { };
      description = ''
        Models advertised to OpenCode. Attribute names are short OpenCode ids.
        Point each entry at a local directory via `path`, a Hugging Face repo via
        `repo`, or omit both and use the attribute name as the Hugging Face id.
        `mlx_lm.server` loads the model from the request body (or `--model` for
        the default).
      '';
      example = {
        "Nemotron-3-Nano" = {
          path = "/Users/me/models/NVIDIA-Nemotron-3-Nano-30B-A3B-MLX-4Bit";
          display-name = "Nemotron 3 Nano";
          context-size = 32768;
          default = true;
        };
        "Llama-3.2-3B" = {
          repo = "mlx-community/Llama-3.2-3B-Instruct-4bit";
          context-size = 8192;
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.homebrew.enable;
        message = "my.services.mlx-lm.enable requires homebrew.enable (mlx-lm is a brew formula).";
      }
      {
        assertion =
          builtins.length
            (
              lib.attrNames (lib.filterAttrs (_: model: model.default) cfg.models)
            ) <= 1;
        message = "my.services.mlx-lm.models allows at most one entry with default = true.";
      }
      {
        assertion = builtins.all
          (model: !(model.path != null && model.repo != null))
          (builtins.attrValues cfg.models);
        message = "my.services.mlx-lm.models entries must not set both path and repo.";
      }
    ];

    homebrew.brews = [ "mlx-lm" ];

    home-manager.users.${env.user} = { lib, ... }: {
      # brew services would start a second mlx_lm.server; this module's launchd agent owns it.
      home.activation.stopBrewMlxLm = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        if [ -x /opt/homebrew/bin/brew ]; then
          $DRY_RUN_CMD /opt/homebrew/bin/brew services stop mlx-lm 2>/dev/null || true
        fi
      '';

      launchd.agents.mlx-lm = {
        enable = true;
        config = {
          Label = "org.mlx.lm.server";
          ProgramArguments = [ cfg.bin ] ++ serverArgs;
          KeepAlive = true;
          RunAtLoad = true;
          WorkingDirectory = env.home;
          EnvironmentVariables.HOME = env.home;
          StandardOutPath = "${env.home}/Library/Logs/mlx-lm.log";
          StandardErrorPath = "${env.home}/Library/Logs/mlx-lm.log";
        };
      };
    };
  };
}
