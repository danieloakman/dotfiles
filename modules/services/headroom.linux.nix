# Headroom — local LLM context compression proxy + CLI.
# https://headroomlabs.ai
#
# The proxy runs directly from the uvx-based `headroom` CLI (same package pinned
# in _package.nix), as a home-manager user service for ${env.user}. No container:
# the CLI and MCP server already resolve via uvx, so the proxy shares one version
# pin instead of drifting against a separate image tag.
#
# Running as the login user means the proxy, `headroom learn`, and the `headroom`
# CLI all share one workspace (~/.headroom) and see the same ~/.claude transcripts
# and PATH (incl. rtk) — so the learned verbosity profile needs no cross-user sync.
#
# Owns Claude Code API routing via ANTHROPIC_BASE_URL while enabled; cannot be
# combined with a separate local-llama ANTHROPIC_BASE_URL for the same client.
#
# Listens on 0.0.0.0 so tailnet peers can open http://<host>:<port>/dashboard
# (per-host, no shared VIP). The firewall only opens the port on the trusted
# tailscale0 interface; LAN/public stay blocked. The proxy is unauthenticated, so
# anything on the tailnet can use it and read stored context.
{ config, pkgs, lib, env, ... }:
let
  cfg = config.my.services.headroom;
  portStr = toString cfg.port;
  # Local clients (Claude via ANTHROPIC_BASE_URL) always use loopback.
  baseUrl = "http://${cfg.host}:${portStr}";

  headroomCli = pkgs.callPackage ./headroom/_package.nix { };

in
{
  options.my.services.headroom = {
    enable = lib.mkEnableOption ''
      Headroom context-compression proxy and CLI (`headroom`), run from the uvx
      package as ${env.user}'s user service. Enabling it always wires the agents:
      Claude Code is routed through the proxy (plus Claude-only MCP for CCR).
      Also reachable on the tailnet at http://<host>:<port>/dashboard.
    '';

    port = lib.mkOption {
      type = lib.types.port;
      default = 19838;
      description = "Host port mapped to the Headroom proxy.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Loopback address local clients use to reach the proxy.";
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
          assertion = config.my.programs.agents.enable;
          message = "my.services.headroom.enable requires my.programs.agents.enable.";
        }
      ];

      # The proxy is a user service (below); linger keeps it running from boot
      # without an interactive login session for ${env.user}.
      users.users.${env.user}.linger = true;

      # Open explicitly on tailscale0 so exposure survives a change to trustedInterfaces.
      networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ cfg.port ];

      home-manager.users.${env.user} = { lib, ... }: {
        home.packages = [ cfg.package ];

        # `headroom mcp install` writes a user-scope entry into ~/.claude.json that
        # points at a uv cache venv (~/.cache/uv/archive-v0/…/bin/headroom). Once uv
        # prunes that venv the shebang python is gone and the server dies with
        # "Connection closed". It also shadows the managed (Nix-pinned) entry.
        # Drop only entries that point into the uv cache.
        home.activation.removeStaleHeadroomMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          f="$HOME/.claude.json"
          if [ -f "$f" ] && ${pkgs.jq}/bin/jq -e \
            '.mcpServers.headroom.command // "" | test("/\\.cache/uv/archive-v0/")' "$f" >/dev/null 2>&1; then
            tmp="$(mktemp "$f.XXXXXX")"
            if ${pkgs.jq}/bin/jq 'del(.mcpServers.headroom)' "$f" > "$tmp"; then
              chmod --reference="$f" "$tmp" && mv "$tmp" "$f"
            else
              rm -f "$tmp"
            fi
          fi
        '';

        # Runs as ${env.user}, so HOME=~ resolves the workspace to ~/.headroom —
        # shared with `headroom learn` and the CLI (no cross-user profile sync).
        systemd.user.services.headroom = {
          Unit.Description = "Headroom LLM context compression proxy";
          Service = {
            ExecStart = "${lib.getExe cfg.package} proxy";
            Environment = [
              "HEADROOM_TELEMETRY=off"
              "HEADROOM_HOST=0.0.0.0"
              "HEADROOM_PORT=${portStr}"
              # Match the old Docker image (0.5.25) default: compress history for
              # token savings. Newer CLI defaults to cache mode (prefix-freeze),
              # which yields $0 compression — pin token so behavior stays the same.
              "HEADROOM_MODE=token"
              # Opt into output-token shaping; reads the level from ~/.headroom/
              # verbosity.json (written by `headroom learn --verbosity`), else its
              # built-in default.
              "HEADROOM_OUTPUT_SHAPER=1"
            ];
            Restart = "on-failure";
            RestartSec = 5;
            # uvx resolves and caches the CLI on first start; allow for the download.
            TimeoutStartSec = 300;
          };
          Install.WantedBy = [ "default.target" ];
        };
      };

      my.services.appctl.services.headroom = {
        description = "Headroom LLM proxy";
        units = [ "headroom.service" ];
        scope = "user";
        inherit (env) user;
        memoryHigh = "2G";
        oomScoreAdjust = 300;
      };

      my.services.homepage.services."Headroom" = {
        description = "LLM context compression proxy";
        href = "http://${config.networking.hostName}:${portStr}/dashboard";
        group = "AI";
        icon = "mdi-brain";
      };

      my.programs.webapps."Headroom" = {
        url = "http://localhost:${portStr}/dashboard";
        icon = "executable";
      };
    }

    {
      my.programs.agents.sandbox.extra-allowed-domains = {
        "127.0.0.1" = "*";
        localhost = "*";
      };

      my.programs.claude-code.managed-settings.env = {
        ANTHROPIC_BASE_URL = baseUrl;
        ENABLE_TOOL_SEARCH = "true";
        # Headroom rewrites request bodies/responses, so auto mode's server-side
        # review (verdicts ride the normal model request) yields "no verdict" and
        # every action is denied. Use Claude Code's own classifier requests instead.
        CLAUDE_CODE_AUTO_MODE_SERVER = "0";
      };

      # Claude-only: CCR retrieve after proxy compression. Not via agents.mcp —
      # Cursor never routes through the proxy, so shared ~/.cursor/mcp.json would
      # only add tool-schema token tax.
      home-manager.users.${env.user}.programs.claude-code.mcpServers.headroom = {
        type = "stdio";
        command = lib.getExe cfg.package;
        args = [
          "mcp"
          "serve"
          "--proxy-url"
          baseUrl
        ];
      };
    }
  ]);
}
