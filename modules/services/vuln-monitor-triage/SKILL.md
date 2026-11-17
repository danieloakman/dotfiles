---
name: vuln-monitor-triage
description: >-
  Triage vuln-monitor feed hits and vulnix findings against this flake: pick
  not_affected, easy_fix (PR), or needs_review; emit a final JSON verdict.
  Use when the vuln-monitor timer launches cursor-agent, or when classifying
  whether a security advisory needs a Nix/dotfiles change on these hosts.
---

# vuln-monitor-triage

Triage the inbox JSON for **this flake** (hosts under `hosts/`, modules under
`modules/`). Finish with a single JSON verdict object as the last line of
stdout. The systemd wrapper parses that line and decides Telegram / PR follow-up.

## Inputs (environment)

| Var | Meaning |
| --- | --- |
| `VULN_INBOX` | Path to inbox JSON (required) |
| `VULN_KIND` | `feeds` or `vulnix` |
| `VULN_HOST` | Short hostname that raised the alert (usually `mara`) |
| `VULN_WORKTREE` | Isolated git worktree for easy_fix only |
| `VULN_REPO` | Interactive checkout path (read reference only; never commit here) |

Read the inbox once. Shape:

```json
{
  "kind": "feeds",
  "host": "mara",
  "items": [
    {
      "key": "oss-security:…",
      "source": "oss-security",
      "title": "…",
      "link": "https://…"
    }
  ]
}
```

Vulnix items use `key`, `pname`, `name`, `cve`, `score` instead of
`source`/`title`/`link` (NVD URL is derived from `cve`).

Host policy and known safe defaults: [reference.md](reference.md).

## Verdicts

Exactly one of:

| `verdict` | When | Side effects |
| --- | --- | --- |
| `not_affected` | This flake/host is clearly not exposed; no config change needed | None |
| `easy_fix` | Small, local, reversible Nix/dotfiles change closes or hardens the issue | Commit + `gh pr create` **in `$VULN_WORKTREE` only** |
| `needs_review` | Affected or unclear; fix is large, risky, or needs human judgement | None |

**Easy fix bar:** flip a known option, pin/bump an already-packaged version in
this flake, or add a justified `ignore-cves` / whitelist entry when the finding
is a false positive *for this flake*. Not easy: kernel/ABI upgrades, multi-host
redesign, new secrets, anything that needs more than `just check-host` to
validate, speculative dependency rewrites.

When several items arrive together: pick the **strictest** overall verdict
(`needs_review` > `easy_fix` > `not_affected`). Per-item notes go in `items`.

## Workflow

1. Read `$VULN_INBOX`. Open each item’s link (or NVD page) enough to understand
   the condition of exploitation.
2. Map conditions onto this flake: search `hosts/`, `modules/services/ssh.nix`,
   package pins, and [reference.md](reference.md). Prefer evidence from the
   repo over guesses.
3. Choose the overall `verdict`.
4. If `easy_fix`:
   - Work only in `$VULN_WORKTREE` (already on a fresh `vuln-monitor/…` branch
     from `origin/main`). Leave `$VULN_REPO` untouched.
   - Apply the minimal change. Run `just check-host` when the change is Nix
     eval–relevant; if check fails, stop and switch to `needs_review` (no PR).
   - Commit with a concise why-focused message. Push and
     `gh pr create` (body = summary + item links). Set `pr_url` to the PR URL.
   - If `gh` / push fails after a good local commit: set `verdict` to
     `needs_review`, put the intended diff summary in `summary`, leave
     `pr_url` null.
5. Print the JSON object as the **final line** of stdout (no fence).

## Output schema

```json
{
  "verdict": "not_affected",
  "summary": "one short paragraph",
  "affected_hosts": ["mara"],
  "pr_url": null,
  "items": [{ "key": "…", "note": "…" }]
}
```

- `not_affected`: `affected_hosts` may be `[]`; `pr_url` null.
- `easy_fix`: `pr_url` must be a real HTTPS PR URL.
- `needs_review`: `pr_url` null; `summary` must say what a human should check.

## Guardrails

- Commit and push only inside `$VULN_WORKTREE`.
- Do not run `just switch` / `nh os switch` / reboot.
- Do not edit sops secrets or `/run/secrets`.
- Do not force-push or amend remote history.
- Keep `summary` short enough for Telegram (~500 chars).
