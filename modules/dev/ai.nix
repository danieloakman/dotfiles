{ pkgs, env, config, ... }:
let
  # When llama-cpp.nix is used, default claude-local model to first configured model name (llama-swap key).
  defaultLocalModel =
    let
      models = (config.services.llama-cpp or { }).models or { };
      names = builtins.attrNames models;
    in
    if names != [ ] then builtins.head names else "local";
  gcalcliSkill = ''
    ---
    name: gcalcli
    description: Use gcalcli to list, add, edit, and search Google Calendar events from the command line. Use when the user mentions gcalcli, Google Calendar CLI, calendar agenda, quick-add events, gcalctl, or scripting calendar access from the terminal.
    ---

    # gcalcli

    Command-line interface to Google Calendar (Python CLI). Use for agenda, quick-add, add/edit/delete, search, and reminders.

    ## Subcommands (quick reference)

    | Command   | Purpose |
    |----------|---------|
    | `agenda` | Events for a time range (default: next 7 days) |
    | `calw`   | Week view (ASCII); `calw N` = N weeks |
    | `calm`   | Month view (ASCII) |
    | `list`   | List available calendars |
    | `quick`  | Quick-add one event from natural-language string |
    | `add`    | Add event (interactive or with options) |
    | `edit`   | Edit events (search term, interactive) |
    | `delete` | Delete events (search term) |
    | `search` | Search events (case-insensitive) |
    | `import` | Import .ics / vcal from file or stdin |
    | `remind` | Run a command when an event is within N minutes |

    ## Viewing events

    ```bash
    # Next 7 days (default)
    gcalcli agenda

    # Specific date or range (mm/dd [mm/dd])
    gcalcli agenda 3/1 3/7

    # One calendar
    gcalcli --calendar "Work" agenda

    # Week / month view
    gcalcli calw 2
    gcalcli calm
    ```

    ## Adding events

    **Quick-add** (natural language):

    ```bash
    gcalcli quick "Dinner with Alex 7pm tomorrow"
    gcalcli quick "Meeting in Room 4 at 2pm next Monday"
    ```

    **Add** (detailed; use `--details` for non-interactive):

    ```bash
    gcalcli add
    gcalcli --calendar "Work" add --title "Standup" --when "9am" --duration 15
    ```

    ## Calendar selection

    - `--calendar "Calendar Name"` — single calendar (regex supported)
    - `--default-calendar=Name` — default for add/quick
    - Config: `~/.config/gcalcli/config.toml` (or `gcalcli config edit`); e.g. `default-calendars = ["Personal", "Work"]`

    ## Auth and config

    - First run: OAuth in browser. Token stored in platform config (e.g. `~/.local/share/gcalcli/oauth`).
    - Custom OAuth: `gcalcli --client-id=ID --client-secret=SECRET init`
    - Nix/sops: If the system wraps `gcalcli` with client-id/secret from secrets, run the wrapper (e.g. `gcalcli` from the same env that has secrets); don’t hardcode credentials in scripts.
    - Flag file: `gcalcli @path/to/flags add` — file has one option per line (e.g. `--default-calendar=Work`).

    ## Examples

    ```bash
    # Today and tomorrow
    gcalcli agenda "$(date +%m/%d)" "$(date -d tomorrow +%m/%d)"

    # Quick-add to a specific calendar
    gcalcli --calendar "Personal" quick "Gym 6am tomorrow"

    # Search then delete (interactive)
    gcalcli search "old meeting"
    gcalcli delete "old meeting"

    # Remind: run notify-send 10 min before events (e.g. from cron)
    gcalcli remind 10
    ```

    ## Output options

    - `--nocolor` — plain text
    - `--conky` — Conky-friendly color sequences
    - `--detail-url=short` — shorter URLs in output
  '';
in
{
  environment.systemPackages = with pkgs; [
    llmfit # CLI tool to find what LLMs can run on our hardware
    gemini-cli
    cursor-cli
    libnotify # Add `notify-send` command
    opencode # CLI tool to utilise free LLMs to write code

    # Claude Code → local llama (llama-swap in modules/services/llama-cpp.nix). Select model in Llama Swap first. Override: ANTHROPIC_MODEL=<key> claude-local; port: claude-local <port>.
    (writeShellScriptBin "claude-local" ''
      default_port="11344"
      default_model="${defaultLocalModel}"
      port="''${1:-$default_port}"
      if [[ "$port" =~ ^[0-9]+$ ]]; then shift; else port=$default_port; fi
      export ANTHROPIC_BASE_URL="http://127.0.0.1:$port"
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
    programs.claude-code = {
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
      skills = {
        gcalcli = gcalcliSkill;
      };
    };

    home.file.".cursor/skills/gcalcli".text = gcalcliSkill;
  };
}
