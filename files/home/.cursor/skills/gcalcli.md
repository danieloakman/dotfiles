---
name: gcalcli
description: Use gcalcli to list, add, edit, and search Google Calendar events from the command line. Use when the user mentions gcalcli, Google Calendar CLI, calendar agenda, quick-add events, gcalctl, or scripting calendar access from the terminal.
---

# gcalcli

Command-line interface to Google Calendar (Python CLI). Use for agenda, quick-add, add/edit/delete, search, and reminders.

## Subcommands (quick reference)

| Command  | Purpose                                          |
| -------- | ------------------------------------------------ |
| `agenda` | Events for a time range (default: next 7 days)   |
| `calw`   | Week view (ASCII); `calw N` = N weeks            |
| `calm`   | Month view (ASCII)                               |
| `list`   | List available calendars                         |
| `quick`  | Quick-add one event from natural-language string |
| `add`    | Add event (interactive or with options)          |
| `edit`   | Edit events (search term, interactive)           |
| `delete` | Delete events (search term)                      |
| `search` | Search events (case-insensitive)                 |
| `import` | Import .ics / vcal from file or stdin            |
| `remind` | Run a command when an event is within N minutes  |

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

**Add** (detailed):

```bash
gcalcli add
gcalcli --calendar "Work" add --title "Standup" --when "9am" --duration 15
```

- With `--noprompt`: you **must** pass `--duration N` (minutes) or `--end`, otherwise gcalcli errors with "Duration time is invalid: None". Example: `gcalcli --calendar "test" add --title "test" --when "9am tomorrow" --duration 60 --noprompt`.

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

## Deleting events

```bash
gcalcli --calendar "Name" delete "search_text" [start] [end]
```

- **Search**: Case-insensitive; matches event title (and possibly other fields). Without `start`/`end`, lists all matching events and prompts per event.
- **Narrow by date**: Use `start` and `end` in **YYYY-MM-DD** format so only events in that range are shown (e.g. `delete "test" "2026-03-03" "2026-03-04"`). Avoids deleting the wrong event.
- **Confirm non-interactively**: Pipe one `y` to accept: `printf 'y\n' | gcalcli --calendar "test" delete "test" "2026-03-03" "2026-03-04"`.
- **Stored date**: "tomorrow" / natural language can resolve to a different year than you expect. Use `gcalcli --calendar "Name" search "title"` first to see the actual stored date before delete.
- **Skip prompt**: `--iamaexpert` deletes without asking; still use start/end to limit which event is deleted.

## Output options

- `--nocolor` — plain text
- `--conky` — Conky-friendly color sequences
- `--detail-url=short` — shorter URLs in output
