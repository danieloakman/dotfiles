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

  # Rule handed to cursor + opencode (MCP-only agents) telling them to use the
  # Headroom MCP tools. Kept out of ~/.claude/rules so Claude Code never sees it.
  mcpUsageRule = ''
    # Headroom context compression

    A `headroom` MCP server is available. Use its tools aggressively to keep the
    working context small.

    - Before adding large content to context (long file reads, command/log output,
      search results, API/JSON payloads), pass it through `headroom_compress` and
      keep only the returned compact reference.
    - When detail that was compressed away is needed again, call `headroom_retrieve`
      with the reference instead of re-reading the source.
    - Use `headroom_stats` to check context/compression state when unsure.

    Rule: whenever a step would add a large chunk of text that can be summarized or
    fetched on demand, prefer the headroom MCP tools over inlining it. Only skip
    headroom when the content is already small or must be quoted verbatim.
  '';

in
{
  options.my.services.headroom = {
    enable = lib.mkEnableOption ''
      Headroom context-compression proxy and CLI (`headroom`), run from the uvx
      package as ${env.user}'s user service. Enabling it always wires the agents:
      Claude Code is routed through the proxy (plus MCP), while cursor and opencode
      get the Headroom MCP server and a rule telling them to use it. Also reachable
      on the tailnet at http://<host>:<port>/dashboard.
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

      home-manager.users.${env.user} = {
        home.packages = [ cfg.package ];

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

      my.services.homepage.services."Headroom" = {
        description = "LLM context compression proxy";
        href = "http://${config.networking.hostName}:${portStr}/dashboard";
      };

      my.programs.webapps."Headroom" = {
        url = "http://localhost:${portStr}/dashboard";
        icon = "executable";
      };
    }

    {
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

      # cursor and opencode are MCP-only, so a rule nudges them to use the tools;
      # Claude Code auto-compresses via the proxy and is excluded (see mcpUsageRule).
      home-manager.users.${env.user} = lib.mkMerge [
        {
          home.file.".cursor/rules/headroom.md".text = mcpUsageRule;
        }
        (lib.mkIf config.my.programs.opencode.enable {
          # OpenCode has no auto-scanned rules dir, so eager-load the file from
          # AGENTS.md (context is `lines`; mkAfter appends to the rules index).
          home.file.".config/opencode/rules/headroom.md".text = mcpUsageRule;
          programs.opencode.context = lib.mkAfter ''

            Read @~/.config/opencode/rules/headroom.md immediately and treat it as mandatory.
          '';
        })
      ];
    }
  ]);
}
