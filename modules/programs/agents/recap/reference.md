# Recap — reference

## Path mapping from repo absolute path

```bash
REPO_ABS=$(git -C "$REPO" rev-parse --show-toplevel)
# Cursor project slug (no leading dash)
slug=$(echo "$REPO_ABS" | sed 's|^/||' | tr '/' '-')
# /home/dano/repos/personal/dotfiles → home-dano-repos-personal-dotfiles

cursor_projects="$HOME/.cursor/projects/$slug"
cursor_transcripts="$cursor_projects/agent-transcripts"

# Cursor chats metadata hash (md5 of absolute path string)
chats_hash=$(printf '%s' "$REPO_ABS" | md5sum | awk '{print $1}')
cursor_chats="$HOME/.cursor/chats/$chats_hash"

# Claude Code project key (leading dash)
claude_key="-$(echo "$REPO_ABS" | sed 's|^/||' | tr '/' '-')"
claude_dir="$HOME/.claude/projects/$claude_key"
```

Worktrees use the **full absolute path** as the slug (separate Cursor/Claude folders).

## Cursor artifacts

| Path | Role |
|------|------|
| `…/agent-transcripts/<uuid>/<uuid>.jsonl` | Full agent transcript (JSONL) |
| `~/.cursor/chats/<hash>/<uuid>/meta.json` | Title, `updatedAtMs`, `cwd` |
| `~/.cursor/plans/<Title>-<uuid-prefix>.plan.md` | Plans; HTML comment / filename often embeds UUID prefix |

Transcript lines are JSON with `role` and `message.content[]` (`type`: `text`, `tool_use`, …). User text often wraps `<user_query>`.

## Claude Code artifacts

| Path | Role |
|------|------|
| `~/.claude/projects/<claude_key>/<session>.jsonl` | Session transcript |
| `~/.claude/history.jsonl` | Cross-project prompt index (`project`, `sessionId`, `timestamp`) |
| `~/.claude/sessions/<pid>.json` | Live/resume index (cwd, sessionId) |

JSONL entries use `type` (`user`, `assistant`, …), `timestamp`, `cwd`, `sessionId`.

## OpenCode (SQLite — prefer over CLI)

Do **not** rely on `opencode session list` (slow / proxy noise). Query:

- `~/.local/share/opencode/opencode.db` (active)
- `~/.local/share/opencode/opencode-stable.db` (historical)

```sql
SELECT id, title, directory, time_updated
FROM session
WHERE directory = '/abs/path/to/repo'
ORDER BY time_updated DESC
LIMIT 5;
```

`time_updated` is epoch **milliseconds**. Optional last text part:

```sql
SELECT data FROM part
WHERE session_id = 'ses_…'
ORDER BY time_updated DESC
LIMIT 20;
```

Filter `data` JSON for `"type":"text"` client-side; truncate hard.

## Gather helper

`recap-gather` (Nix `writeShellScriptBin` in `recap.nix`) prints markdown sections for git/gh + the three agent stores. Dependencies (`jq`, `sqlite`, `git`, `gh`, coreutils) are pinned via the package. Missing dirs are skipped quietly. Always read-only.

Installed on PATH and substituted into `SKILL.md` as `@recapGather@`.
