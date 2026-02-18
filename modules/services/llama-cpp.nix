{ config, pkgs, lib, env, ... }:
let
  llamaCppPort = 11343;
  llamaSwapPort = 11344;
  host = "0.0.0.0";
in
{
  options = {
    services.llama-cpp = {
      threadCount = lib.mkOption {
        default = 6;
        description = "The number of threads to use for the llama-cpp service";
      };
      gpuLayerCount = lib.mkOption {
        default = 0; # Default 0 layers, meaning CPU-only
        description = "The number of GPU layers to use for the llama-cpp service";
      };
    };
  };
  config = {
    environment.systemPackages = [ pkgs.llama-cpp ];

    services = {
      # Disabled: llama-swap starts llama-server via cmd when a model is requested.
      # Enabling both would have both try to bind to llamaCppPort (11343).
      llama-cpp = {
        enable = false;
        package = pkgs.llama-cpp; # CPU-only by default in nixpkgs
        port = llamaCppPort;
        openFirewall = true;
        host = host;
        extraFlags = [
          "-ngl" # Offload layers to GPU
          "${lib.toString config.services.llama-cpp.gpuLayerCount}"
          "-t"
          "${lib.toString config.services.llama-cpp.threadCount}"
        ];
        # model = defaultModel;
      };
      llama-swap = {
        enable = true;
        port = llamaSwapPort;
        openFirewall = true;
        listenAddress = host;
        settings =
          let
            llama-cpp = pkgs.llama-cpp;
            llama-server = lib.getExe' llama-cpp "llama-server";
            defaultModel = pkgs.fetchurl {
              url = "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf";
              hash = "sha256-b4WmQKl88r9bjnZAh7HoPaD9tR18n6t9D+zpOFYR34M=";
            };
          in
          {
            healthCheckTimeout = 60;
            models = {
              default = {
                cmd = "${llama-server} -m ${defaultModel} --port ${toString llamaCppPort} -ngl ${lib.toString config.services.llama-cpp.gpuLayerCount} -t ${lib.toString config.services.llama-cpp.threadCount}";
                # Default proxy is http://localhost:${PORT}; ${PORT} is only set when cmd uses it.
                # We use a fixed port in cmd, so set proxy explicitly.
                proxy = "http://127.0.0.1:${toString llamaCppPort}";
              };
            } // lib.mkIf env.hasGPU {
              # qwen2_5_coder_7b_instruct =
              #   let
              #     model = pkgs.fetchurl {
              #       url = "https://huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct-GGUF/resolve/main/Qwen2.5-Coder-7B-Instruct-Q8_0.gguf";
              #       hash = "sha256-b4WmQKl88r9bjnZAh7HoPaD9tR18n6t9D+zpOFYR34M=";
              #     };
              #   in
              #   {
              #     cmd = "${llama-server} -m ${model} --port ${toString llamaCppPort} -ngl ${lib.toString config.services.llama-cpp.gpuLayerCount} -t ${lib.toString config.services.llama-cpp.threadCount}";
              #     proxy = "http://127.0.0.1:${toString llamaCppPort}";
              #   };
            };
          };
        tls = {
          enable = false;
          # Perhaps set up these certs in the future if we want tls
          certFile = "/etc/ssl/certs/llama-cpp.crt";
          keyFile = "/etc/ssl/certs/llama-cpp.key";
        };
      };
    };
  };
}
