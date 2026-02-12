{ config, pkgs, lib, ... }:
let
  llamaCppPort = 11343;
  llamaSwapPort = 11344;
  host = "0.0.0.0";

  # Model fetched at build time so `make boot` / `nh os boot` pulls it into the store.
  # Keep hash = lib.fakeSha256 and run your build (e.g. make boot). It will download the file,
  # then fail with "hash mismatch" and print the expected hash. Copy that full value (starts with
  # "sha256-") into the hash = "..." below.
  defaultModel = pkgs.fetchurl {
    url = "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf";
    hash = "sha256-b4WmQKl88r9bjnZAh7HoPaD9tR18n6t9D+zpOFYR34M=";
  };
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
        model = defaultModel;
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
