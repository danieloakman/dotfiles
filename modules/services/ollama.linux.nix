{ env, pkgs, lib, config, ... }:
let
  cfg = config.my.services.ollama;
  ollamaPort = cfg.port;
  ollamaUiPort = cfg.port + 1;
in
{
  options.my.services.ollama = {
    enable = lib.mkEnableOption "Enable the Ollama service";
    port = lib.mkOption {
      type = lib.types.int;
      default = 11434;
      description = "The port to use for the Ollama service. The +1 from this is used for the Ollama UI.";
    };
  };

  config = lib.mkIf config.my.services.ollama.enable {
    services = {
      ollama = {
        port = ollamaPort;
        package = if env.hasGPU then pkgs.ollama else pkgs.ollama-cpu;
        enable = true;
        openFirewall = true;
        host = "127.0.0.1";
        loadModels = [
          # General purpose models:
          "llama3.2"
          "llama3.2:1b"

          # Coding related models:
          "qwen2.5:0.5b"
          "qwen2.5:1.5b"
          "qwen2.5:3b"

          # Structured output models:
          "Osmosis/Osmosis-Structure-0.6B"
        ];
        # CPU-only (no GPU): limit threads so the server stays responsive.
        # Omit or increase if this machine is dedicated to Ollama.
        environmentVariables = {
          OLLAMA_NUM_THREADS = "4";
        };
      };

      nextjs-ollama-llm-ui = {
        enable = true;
        port = ollamaUiPort;
        hostname = "127.0.0.1";
        ollamaUrl = "http://localhost:${toString ollamaPort}";
      };
    };

    # environment.systemPackages = with pkgs; [
    #   (writeShellScriptBin "tailscale-svc-ollama-up" ''
    #     tailscale serve --service=svc:ollama --https=443 127.0.0.1:${toString ollamaPort}
    #   '')
    #   (writeShellScriptBin "tailscale-svc-ollama-down" ''
    #     tailscale serve clear svc:ollama
    #   '')
    # ];

    my.services.homepage.services."Ollama" = {
      description = "LLM Chat, hosted by ${config.networking.hostName}";
      href = "http://${config.networking.hostName}:${toString ollamaUiPort}";
    };
  };
}
