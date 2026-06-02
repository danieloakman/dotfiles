{
  pkgs,
  env,
  config,
  lib,
  ...
}:
let
  enable = config.my.dev.ai.enable;
  # Pin fetchFromGitHub to a commit rev (not a branch) so sha256 stays stable until
  # you bump rev. To upgrade: set rev to the new commit, then run
  #   nix flake prefetch github:owner/repo/<rev>
  # and copy the printed hash into sha256.
  mattpocockSkills =
    (pkgs.fetchFromGitHub {
      # https://github.com/mattpocock/skills/tree/aaf2453fbdfe7a15c07f11d861224f34ab4b53cb/skills
      owner = "mattpocock";
      repo = "skills";
      rev = "aaf2453fbdfe7a15c07f11d861224f34ab4b53cb";
      sha256 = "sha256-+Px3qIMHGKvi0PK2l5H4j/4YRQ448G9kuWX28cgqPCI=";
    })
    + "/skills";
  # Other skill repos that could be added in the future:
  # https://github.com/deepakness/google-ai-search-optimization - AI search optimization and general SEO
in
{
  config = lib.mkIf enable {
    my.dev.ai = {
      rootContext = builtins.readFile (
        builtins.fetchurl {
          url = "https://raw.githubusercontent.com/drona23/claude-token-efficient/702e423f98d0d8963d1b76ac74a66a4f2eed67e8/CLAUDE.md";
          sha256 = "oqokm0Bi63OGF2F/+BvNx40zvlQWqBpYxPm3KbYAgCo=";
        }
      );
      skills = {
        grill-me = mattpocockSkills + "/productivity/grill-me/SKILL.md";
        caveman = mattpocockSkills + "/productivity/caveman/SKILL.md";
        handoff = mattpocockSkills + "/productivity/handoff/SKILL.md";
        write-a-skill = mattpocockSkills + "/productivity/write-a-skill/SKILL.md";
      };
      skillDirs = {
        "ui-design-brain" = pkgs.fetchFromGitHub {
          # https://github.com/carmahhawwari/ui-design-brain/tree/38f04c5a1dee55d99c686a16643cef4e2ce0f7a2
          owner = "carmahhawwari";
          repo = "ui-design-brain";
          rev = "38f04c5a1dee55d99c686a16643cef4e2ce0f7a2";
          sha256 = "sha256-aOeR/qpkM+gRegRDvJp/SxWVEDLwH5pW0d5FbFkv/AE=";
        };
      };
    };

    environment.systemPackages = with pkgs; [
      llmfit # CLI tool to find what LLMs can run on our hardware
      gemini-cli
      libnotify # Add `notify-send` command

      # Claude Code → local llama (llama-swap in modules/services/llama-cpp.nix). Select model in Llama Swap first. Override: ANTHROPIC_MODEL=<key> claude-local; port: claude-local <port>.
      (
        let
          # When llama-cpp.nix is used, default claude-local model to first configured model name (llama-swap key).
          defaultLocalModel =
            let
              models = (config.services.llama-cpp or { }).models or { };
              names = builtins.attrNames models;
            in
            if names != [ ] then builtins.head names else "local";
        in
        writeShellScriptBin "claude-local" ''
          default_port="11343"
          default_model="${defaultLocalModel}"
          port="''${1:-$default_port}"
          if [[ "$port" =~ ^[0-9]+$ ]]; then shift; else port=$default_port; fi
          export ANTHROPIC_BASE_URL="http://localhost:$port"
          export ANTHROPIC_MODEL="''${ANTHROPIC_MODEL:-$default_model}"
          exec claude "$@"
        ''
      )

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
          enable = env.platform != "darwin";
          # Avoid telemetry 404s when using claude-local (ANTHROPIC_BASE_URL → local llama-server)
          settings = {
            env.CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
            includeCoAuthoredBy = false;
            theme = "dark";
            effortLevel = "high"; # Ideally it'd be nice for us to be able to change this ourselves with /effort, but high is alright for now.
          };
          rules = {
            response-to-user = ''
              When reporting information to me, be extremely concise and sacrifice grammar for sake of concision.
            '';
          };
        };

        # Use free or locally hosted LLMs for coding
        opencode = {
          enable = true;
          context = ''
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
  };
}
