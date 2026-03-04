{ pkgs, env, config, ... }:
let
  # When llama-cpp.nix is used, default claude-local model to first configured model name (llama-swap key).
  defaultLocalModel =
    let
      models = (config.services.llama-cpp or { }).models or { };
      names = builtins.attrNames models;
    in
    if names != [ ] then builtins.head names else "local";
in
{
  environment.systemPackages = with pkgs; [
    llmfit # CLI tool to find what LLMs can run on our hardware
    gemini-cli
    cursor-cli
    libnotify # Add `notify-send` command

    # Claude Code → local llama (llama-swap in modules/services/llama-cpp.nix). Select model in Llama Swap first. Override: ANTHROPIC_MODEL=<key> claude-local; port: claude-local <port>.
    (writeShellScriptBin "claude-local" ''
      default_port="11343"
      default_model="${defaultLocalModel}"
      port="''${1:-$default_port}"
      if [[ "$port" =~ ^[0-9]+$ ]]; then shift; else port=$default_port; fi
      export ANTHROPIC_BASE_URL="http://localhost:$port"
      export ANTHROPIC_MODEL="''${ANTHROPIC_MODEL:-$default_model}"
      exec claude "$@"
    '')

    # Ralph AI loop: run `ralph <iterations>` in a project with plans/prd.json and progress.md
    (writeShellScriptBin "ralph" ''
      set -e
      iterations=""
      force=""
      for arg in "$@"; do
        if [ "$arg" = "--force" ]; then force="--force"; elif [ -z "$iterations" ]; then iterations="$arg"; fi
      done
      if [ -z "$iterations" ]; then
        echo "Usage: ralph [--force] <iterations>"
        exit 1
      fi

      for i in $(seq 1 "$iterations"); do
        echo "Iteration $i"
        echo "----------------------------------------"
        result=$(cursor-agent $force -p "@plans/prd.json @progress.md
      1. Find the highest-priority feature to work on and work only on that feature. This should be the one YOU decide has the highest priority - not necessarily the first in the list.
      2. Check that the types check via \`bun typecheck\` and that the tests pass via \`bun test\`.
      3. Update the PRD with the work that was done.
      4. Append your progress to the \`progress.md\` file. Use this to leave a note for the next person working in the codebase.
      5. Make a git commit of that feature.
      ONLY WORK ON A SINGLE FEATURE.
      If, while implementing the feature, you notice the PRD is complete, output <promise>COMPLETE</promise>.
      ")
        echo "$result"
        if echo "$result" | grep -q "<promise>COMPLETE</promise>"; then
          echo "PRD complete, exiting."
          notify-send "Ralph" "PRD complete after $i iterations" 2>/dev/null || true
          exit 0
        fi
      done
    '')
  ];

  home-manager.users.${env.user} = {
    programs = {
      claude-code = {
        enable = true;
        # Avoid telemetry 404s when using claude-local (ANTHROPIC_BASE_URL → local llama-server)
        settings = { env.CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1"; };
        rules = {
          response-to-user = ''
            When reporting information to me, be extremely concise and sacrifice grammar for sake of concision.
          '';
        };
        mcpServers = {
          google-calendar = {
            command = "npx";
            args = [ "@cocal/google-calendar-mcp" ];
            env = {
              GOOGLE_OAUTH_CREDENTIALS = config.sops.secrets."google_calendar_mcp_oath.json".path;
            };
          };
        };
      };

      # Use free or locally hosted LLMs for coding
      opencode = {
        enable = true;
        rules = ''
          When reporting information to me, be extremely concise and sacrifice grammar for sake of concision.
        '';
        # programs.mcp.servers are merged with opencodes mcp servers settings:
        enableMcpIntegration = true;
        settings = {
          provider = {
            # TODO: add support for local llama-cpp models.
            llama.options = {
              url = "http://localhost:11343/v1";
              model = "DeepSeek-R1-Distill-Qwen-7B-Q6_K";
            };
          };
        };
      };
    };
  };
}
