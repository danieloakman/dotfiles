# Headroom — local LLM context compression proxy + CLI.
# https://headroomlabs.ai
#
# Owns Claude Code API routing via ANTHROPIC_BASE_URL while enabled; cannot be
# combined with a separate local-llama ANTHROPIC_BASE_URL for the same client.
#
# Listens on 0.0.0.0 so tailnet peers can open http://<host>:<port>/dashboard
# (per-host, no shared VIP). The firewall only opens the port on the trusted
# tailscale0 interface; LAN/public and other containers stay blocked. The proxy
# is unauthenticated — anything on the tailnet can use it and read stored context.
{ config, pkgs, lib, env, ... }:
let
  cfg = config.my.services.headroom;
  portStr = toString cfg.port;
  # Local clients (Claude via ANTHROPIC_BASE_URL) always use loopback.
  baseUrl = "http://${cfg.host}:${portStr}";
  containerName = "headroom";

  headroomCli = pkgs.callPackage ./headroom/_package.nix { };

  # Host networking (not a published bridge port) so a bridge-IP listener isn't
  # reachable by other containers. Bind 0.0.0.0; firewall limits to tailscale0.
  startScript = pkgs.writeShellScript "headroom-docker-run" ''
    set -euo pipefail
    ${lib.getExe pkgs.docker} rm -f ${containerName} >/dev/null 2>&1 || true
    exec ${lib.getExe pkgs.docker} run --rm --name ${containerName} \
      --network host \
      -v /var/lib/headroom:/root/.headroom \
      -e HEADROOM_TELEMETRY=off \
      -e HEADROOM_HOST=0.0.0.0 \
      -e HEADROOM_PORT=${lib.escapeShellArg portStr} \
      ${lib.escapeShellArg cfg.image}
  '';

  stopScript = pkgs.writeShellScript "headroom-docker-stop" ''
    set -euo pipefail
    ${lib.getExe pkgs.docker} rm -f ${containerName} >/dev/null 2>&1 || true
  '';
in
{
  options.my.services.headroom = {
    enable = lib.mkEnableOption ''
      Headroom context-compression proxy (Docker) and CLI (`headroom`). Claude Code
      is routed through the proxy when wireAgents is true; cursor-agent gets MCP only.
      Also reachable on the tailnet at http://<host>:<port>/dashboard.
    '';

    port = lib.mkOption {
      type = lib.types.port;
      default = 8787;
      description = "Host port mapped to the Headroom proxy.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Loopback address local clients use to reach the proxy.";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "ghcr.io/chopratejas/headroom:0.6.7-code";
      description = ''
        Pinned Headroom container image. Note: the Docker image versioning is
        independent of the PyPI CLI version pinned in _package.nix.
      '';
    };

    wireAgents = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        When true, register Headroom MCP for shared agents and set Claude Code
        managed-settings env (ANTHROPIC_BASE_URL, ENABLE_TOOL_SEARCH). Also allows
        loopback in agent sandboxes so sandboxed Claude can reach the proxy.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = headroomCli;
      description = "Headroom CLI package installed on PATH when the service is enabled.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [
        {
          assertion = config.my.services.docker.enable;
          message = "my.services.headroom.enable requires my.services.docker.enable.";
        }
        {
          assertion = !cfg.wireAgents || config.my.programs.agents.enable;
          message = "my.services.headroom.wireAgents requires my.programs.agents.enable.";
        }
      ];

      my.services.docker.enable = lib.mkDefault true;

      systemd.tmpfiles.rules = [ "d /var/lib/headroom 0755 root root -" ];

      systemd.services.headroom = {
        description = "Headroom LLM context compression proxy";
        after = [
          "network-online.target"
          "docker.service"
        ];
        wants = [ "network-online.target" ];
        requires = [ "docker.service" ];
        wantedBy = [ "multi-user.target" ];
        path = [ pkgs.docker ];
        serviceConfig = {
          Type = "simple";
          Restart = "on-failure";
          RestartSec = "5s";
          ExecStart = "${startScript}";
          ExecStop = "${stopScript}";
          TimeoutStartSec = "120";
        };
      };

      # Open explicitly on tailscale0 so exposure survives a change to trustedInterfaces.
      networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ cfg.port ];

      home-manager.users.${env.user}.home.packages = [ cfg.package ];

      my.services.homepage.services."Headroom" = {
        description = "LLM context compression proxy";
        href = "http://${config.networking.hostName}:${portStr}/dashboard";
      };

      my.programs.webapps."Headroom" = {
        url = "http://localhost:${portStr}/dashboard";
        icon = "executable";
      };
    }

    (lib.mkIf cfg.wireAgents {
      # Headroom's MCP transport is stdio (`headroom mcp serve`), not an HTTP
      # endpoint on the proxy port. See the canonical server.json / README contract.
      my.programs.agents.mcp.headroom = {
        command = lib.getExe cfg.package;
        args = [ "mcp" "serve" ];
      };

      my.programs.agents.sandbox.extraAllowedDomains = {
        "127.0.0.1" = "*";
        localhost = "*";
      };

      my.programs.claude-code.managedSettings.env = {
        ANTHROPIC_BASE_URL = baseUrl;
        ENABLE_TOOL_SEARCH = "true";
      };
    })
  ]);
}
