{ env, pkgs, ... }:
let
  ollamaPort = 11434;
  ollamaUiPort = 11534;
in
{
  services = {
    ollama = {
      port = ollamaPort;
      package = if env.hasGPU then pkgs.ollama else pkgs.ollama-cpu;
      enable = true;
      openFirewall = true;
      host = "0.0.0.0";
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
      hostname = "0.0.0.0";
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
}
