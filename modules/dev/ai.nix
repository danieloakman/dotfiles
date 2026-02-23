{ pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    # llmfit # CLI tool to find what LLMs can run on our hardware
    gemini-cli
    # claude-code
    cursor-cli
    libnotify # Add `notify-send` command

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
}
