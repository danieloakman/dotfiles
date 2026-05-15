{ config, pkgs, lib, env, inputs, system, ... }:
let
  cfg = config.my.services.llama-cpp;
  llamaCppPort = cfg.port;
  llamaSwapPort = cfg.port + 1;
  host = "127.0.0.1";
  # nixpkgs default CUDA archs omit Pascal (6.1); include 61 for GTX 1080 Ti and similar.
  importedLlamaCpp = import inputs.llama-cpp {
    inherit system;
    config.allowUnfree = true;
  };
  baseLlamaCpp = importedLlamaCpp.llama-cpp.override { cudaSupport = env.hasGPU; };
  llamaCppPkg =
    if env.hasGPU then
      baseLlamaCpp.overrideAttrs
        (prev: {
          cmakeFlags = (prev.cmakeFlags or [ ]) ++ [ "-DCMAKE_CUDA_ARCHITECTURES=61;75;80;86;89;90" ];
        }) else baseLlamaCpp;
in
{
  options.my = {
    services.llama-cpp = {
      enable = lib.mkEnableOption "Enable the Llama-CPP/Llama-Swap service";
      port = lib.mkOption {
        type = lib.types.int;
        default = 11343;
        description = "The port to use for Llama-CPP service. The +1 from this is used for Llama-Swap.";
      };
      cpuCoreCount = lib.mkOption {
        default = 1;
        description = "The number of physical CPU cores to use for the llama-cpp service";
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
            extraServerArgs = lib.mkOption { type = lib.types.listOf lib.types.str; default = [ ]; description = "Extra args for llama-server (e.g. [ \"-c\" \"4096\" \"--parallel\" \"1\" ])"; };
          };
        });
        default = { };
        description = "Models for llama-swap (url+hash fetched; optional aliases, proxy, concurrencyLimit)";
      };
    };
  };
  config = lib.mkIf config.my.services.llama-cpp.enable ({
    environment.systemPackages = with pkgs; [
      llamaCppPkg
      python313Packages.huggingface-hub
    ];
    systemd.services.llama-swap.path = builtins.attrValues (builtins.mapAttrs (name: model: model.path) cfg.models);

    services = {
      llama-cpp = {
        # Disabled: llama-swap starts llama-server via cmd when a model is requested.
        # Enabling both would have both try to bind to llamaCppPort (11343).
        enable = false;
        package = llamaCppPkg;
        port = llamaCppPort;
        openFirewall = true;
        inherit host;
        extraFlags = [
          "-ngl" # Offload layers to GPU
          "${lib.toString config.services.llama-cpp.gpuLayerCount}"
          "-t"
          "${lib.toString config.services.llama-cpp.cpuCoreCount}"
        ];
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
              (_: model: {
                cmd = "${llama-server} --port ${toString llamaCppPort} --host ${host} -m ${model.path} -ngl ${lib.toString cfg.gpuLayerCount} -t ${lib.toString cfg.cpuCoreCount} ${lib.escapeShellArgs model.extraServerArgs}";
                proxy = "http://${host}:${toString llamaCppPort}";
              } // lib.optionalAttrs (model.aliases != [ ]) { aliases = model.aliases; }
              // lib.optionalAttrs (model.proxy != null) { proxy = model.proxy; }
              // lib.optionalAttrs (model.concurrencyLimit != null) { concurrencyLimit = model.concurrencyLimit; }
              )
              cfg.models;
          };
        tls = {
          enable = false;
          # Perhaps set up these certs in the future if we want tls
          certFile = "/etc/ssl/certs/llama-cpp.crt";
          keyFile = "/etc/ssl/certs/llama-cpp.key";
        };
      };
    };

    my = {
      services.homepage.services."Llama Swap" = {
        description = "Llama Chat";
        href = "http://${config.networking.hostName}:${toString llamaSwapPort}";
      };
      programs.webapps = {
        "Llama Swap" = {
          url = "http://localhost:${toString llamaSwapPort}";
          icon = "executable";
        };
      } // lib.concatMapAttrs (name: _: {
        "Llama Chat with ${name}" = {
          url = "http://localhost:${toString llamaSwapPort}/upstream/${name}";
          icon = "executable";
        };
      }) cfg.models;
    };
  });
}
