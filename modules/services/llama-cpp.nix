{ config, pkgs, lib, env, ... }:
let
  llamaCppPort = 11343;
  llamaSwapPort = 11344;
  host = "0.0.0.0";
  # nixpkgs default CUDA archs omit Pascal (6.1); include 61 for GTX 1080 Ti and similar.
  baseLlamaCpp = pkgs.llama-cpp.override { cudaSupport = env.hasGPU; };
  llamaCppPkg = if env.hasGPU then baseLlamaCpp.overrideAttrs (prev: {
    cmakeFlags = (prev.cmakeFlags or [ ]) ++ [ "-DCMAKE_CUDA_ARCHITECTURES=61;75;80;86;89;90" ];
  }) else baseLlamaCpp;
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
      models = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            path = lib.mkOption { type = lib.types.path; description = "Path to the GGUF model"; };
            aliases = lib.mkOption { type = lib.types.listOf lib.types.str; default = [ ]; description = "Optional aliases for this model"; };
            proxy = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; description = "Override proxy URL"; };
            concurrencyLimit = lib.mkOption { type = lib.types.nullOr lib.types.int; default = null; description = "Max concurrent requests"; };
          };
        });
        default = { };
        description = "Models for llama-swap (url+hash fetched; optional aliases, proxy, concurrencyLimit)";
      };
    };
  };
  config =
    {
      environment.systemPackages = with pkgs; [
        llamaCppPkg
        python313Packages.huggingface-hub
      ];
      systemd.services.llama-swap.path = builtins.attrValues (builtins.mapAttrs (name: model: model.path) config.services.llama-cpp.models);

      services = {
        # Disabled: llama-swap starts llama-server via cmd when a model is requested.
        # Enabling both would have both try to bind to llamaCppPort (11343).
        llama-cpp = {
          enable = false;
          package = llamaCppPkg;
          port = llamaCppPort;
          openFirewall = true;
          inherit host;
          extraFlags = [
            "-ngl" # Offload layers to GPU
            "${lib.toString config.services.llama-cpp.gpuLayerCount}"
            "-t"
            "${lib.toString config.services.llama-cpp.threadCount}"
          ];
          model = config.services.llama-cpp.models.default;
        };
        llama-swap = {
          enable = true;
          port = llamaSwapPort;
          openFirewall = true;
          listenAddress = host;
          settings =
            let
              llama-server = lib.getExe' llamaCppPkg "llama-server";
            in
            {
              healthCheckTimeout = 60;
              models = builtins.mapAttrs
                (name: model: {
                  cmd = "${llama-server} --port ${toString llamaCppPort} -m ${model.path} -ngl ${lib.toString config.services.llama-cpp.gpuLayerCount} -t ${lib.toString config.services.llama-cpp.threadCount}";
                  proxy = "http://${host}:${toString llamaCppPort}";
                } // lib.optionalAttrs (model.aliases != [ ]) { aliases = model.aliases; }
                // lib.optionalAttrs (model.proxy != null) { proxy = model.proxy; }
                // lib.optionalAttrs (model.concurrencyLimit != null) { concurrencyLimit = model.concurrencyLimit; }
                )
                config.services.llama-cpp.models;
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
