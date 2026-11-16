---
name: gmail-api
description: >-
  Search, read, and download Gmail attachments via the gmail-api CLI
  (token-efficient). Prefer this over the gws skill for Gmail search/list/read/
  attachments. Use gws instead for send, reply, forward, labels, filters, watch,
  and non-Gmail Workspace.
---

# gmail-api

`gmail-api` is on PATH (Nix `bun-scripts`). Prefer it over `gws gmail +triage` / `+read` for search, read, and attachment download.

## Hard rules for agents

- Prefer **`search -j`** then **`read -j`** — never dump HTML unless the user asks.
- Do **not** use `-H` / `--html` unless explicitly needed (blows context).
- Search is metadata-only (`+triage` under the hood). Full body only via `read`.
- Attachments: **`attachments <id> -j`** then **`download <id> <filename>`** — never paste binary into chat.
- For send/reply/labels/filters → load the **gws** skill, not this one.

## Search

```bash
gmail-api search [keywords...] [flags]
gmail-api search -j -m 10 invoice
gmail-api search -f boss@example.com -s "receipt" -a 2025/01/01 -j
```

| Flag | Short | Meaning |
|------|-------|---------|
| `--from` | `-f` | `from:` |
| `--to` | `-t` | `to:` |
| `--subject` | `-s` | `subject:` |
| `--after` | `-a` | `after:YYYY/MM/DD` |
| `--before` | `-b` | `before:YYYY/MM/DD` |
| `--query` | `-q` | raw Gmail query fragment (AND) |
| `--max` | `-m` | max results (default 20) |
| `--json` | `-j` | compact JSON summaries |
| `--list` | `-l` | human listing (no picker) |

JSON hits: `{ query, messages: [{ id, from, subject, date }] }`.

Without `-j`/`-l`, interactive fzf/rofi pick then full-reads the chosen message (human use).

## Read

```bash
gmail-api read <id> -j
gmail-api read <id> -jF    # full bodyText (no 4k truncate)
gmail-api read <id> -jH    # include bodyHtml — avoid unless needed
```

`read -j` returns compact JSON: `id`, `subject`, `from`, `to`, `date`, `bodyText`.
Bodies over 4k chars are truncated unless `-F`; then `truncated` + `bodyLength` appear.
`read` does **not** include attachment metadata — use `attachments`.

## Attachments

```bash
gmail-api attachments <id> -j
gmail-api download <id> invoice.pdf
gmail-api download <id> -a -o ./inbox/
gmail-api download <id> -j          # sole attachment → ./<filename>
```

`attachments -j` → `{ id, attachments: [{ id, filename, mimeType, size, inline }] }`.
`download` writes decoded bytes to disk (default `./<filename>`). Selector is filename or attachment `id`; omit when there is exactly one. `--all` / `-a` downloads every part; `-o` is a file path (single) or `directory/` (trailing slash, or with `--all`).

## Typical agent flow

```bash
gmail-api search invoice -f exetel -j -m 5
gmail-api read 1a13e1eda3357799 -j
gmail-api attachments 1a13e1eda3357799 -j
gmail-api download 1a13e1eda3357799 statement.pdf -o ./statement.pdf
```
