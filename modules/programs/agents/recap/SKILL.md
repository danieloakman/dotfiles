---
name: recap
description: >-
  Recap where work left off in the current repo: git state, GitHub PRs/issues,
  and recent Cursor/Claude/OpenCode agent sessions, then recommend how to
  continue. Use when invoked as /recap, or when returning to a project,
  catching up, resuming work, asking where you left off, or requesting a
  project recap.
---

# Recap

Repo-wide “where did I leave off?” — not a conversation handoff.

| Skill | Purpose |
|-------|---------|
| **recap** (`/recap`) | Cross-session repo state + agent history → how to continue |
| **handoff** | Compact *this* chat for the next agent |

## Quick start

1. Resolve repo root: `git rev-parse --show-toplevel` (else cwd).
2. Run the gather helper (read-only index; Nix-wrapped with jq/sqlite/git/gh):

```bash
@recapGather@
# Also on PATH after home-manager switch:
recap-gather
```

Optional: `REPO=/path/to/repo recap-gather` or `recap-gather /path/to/repo`.

3. From the index, pick the **1–3** most relevant agent sessions (recency + title overlap with dirty files / branch / open PR). Read only those transcript **tails** — never dump full histories.
4. Synthesize the recap template below. Be concise.
5. **Do not write a file** unless the user asks to save (see Save).

## Output template

```markdown
## Last context
[What was in flight — chats + dirty tree + open PR]

## Repo state
[Branch, dirty files, recent commits, open PRs/issues]

## Agent history
[Cursor / Claude / OpenCode — title, when, one-line gist]

## Blockers
[Failing checks, conflicts, missing secrets, TODOs from last chat — or “none obvious”]

## Continue here
1. [Most concrete next action]
2. …
3. …

## Suggested skills
[Only if relevant, e.g. edit-sops-secrets, handoff — else omit section]
```

## Guardrails

- **Read-only:** no git mutations, no commits, no stash apply/pop, no pushing.
- **Redact** secrets, tokens, credentials; cite paths/URLs instead of pasting huge diffs.
- **Omit** empty sources (no Claude sessions → skip Claude).
- Prefer pointers into existing artifacts (plans, PRs, issues) over re-deriving them.

## Save (only on request)

If the user asks to save the recap (“save this”, “write it down”, etc.):

- Default path: `$TMPDIR/recap-<repo-name>-<YYYYMMDD>.md` (or `/tmp/...`)
- Or the path they name
- Confirm the path after writing

Do **not** commit the note or add it to the repo unless they explicitly ask.

## Deeper reference

Path mapping, OpenCode SQL, transcript formats: [reference.md](reference.md)
