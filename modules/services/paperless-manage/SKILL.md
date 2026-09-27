---
name: paperless-manage
description: >-
  Run Paperless-ngx admin tasks via the NixOS paperless-manage wrapper
  (export/import, reindex, retag, sanity check, mail fetch, superuser). Use when
  the user mentions paperless-manage, paperless-ngx maintenance, document export,
  search index, or Paperless CLI on this host.
---

# paperless-manage

## When to use

NixOS wraps Paperless Django management commands as `paperless-manage`. Use it
for ops/admin work — not day-to-day browsing (use the web UI / API for that).

Service config: `modules/services/paperless.linux.nix`.
UI: `https://@domain@`

## How to invoke

Prefer the system wrapper (env, dirs, and redis already set):

```bash
paperless-manage <subcommand> [args...]
paperless-manage help
paperless-manage help <subcommand>
```

**If** you see `Permission denied` on
`/var/lib/paperless/nixos-paperless-secret-key.env`, the wrapper sourced the key
as your user before dropping to `paperless`. Re-run as the service user:

```bash
sudo -u paperless -g paperless paperless-manage <subcommand> [args...]
```

Must run on the host where Paperless is enabled. Do not invent Docker
`compose exec` paths for this install.

## Safe defaults

- Prefer read-only / diagnostic commands first (`help`, `document_sanity_checker`,
  `showmigrations`) before destructive ones.
- For export/import/rename: confirm target paths with the user; never overwrite
  unknown directories with `--delete` without explicit approval.
- Do not print secrets, DB dumps, or export passphrases into chat.
- Long jobs (reindex, archiver, full export): set a high shell
  `block_until_ms` / run in background and monitor.

## Common tasks

| Goal | Command |
| --- | --- |
| List commands | `paperless-manage help` |
| Create admin user | `paperless-manage createsuperuser` |
| Backup / export | `paperless-manage document_exporter /path/to/export` |
| Restore / import | `paperless-manage document_importer /path/to/export` |
| Rebuild search index | `paperless-manage document_index reindex` |
| Optimize search index | `paperless-manage document_index optimize` |
| Sanity check media/DB | `paperless-manage document_sanity_checker` |
| Re-apply matching rules | `paperless-manage document_retagger -c -T -t` |
| Train auto-matcher | `paperless-manage document_create_classifier` |
| Fetch mail now | `paperless-manage mail_fetcher` |
| Regenerate thumbnails | `paperless-manage document_thumbnails` |
| Create PDF/A archives | `paperless-manage document_archiver` |
| Rename files after format change | `paperless-manage document_renamer` |

Export flags worth knowing: `-d`/`--delete` (remove stale export files),
`-z`/`--zip`, `--data-only`, `--no-progress-bar` (good for scripts).

Import expects an **empty** DB/install unless `--data-only`.

## Layout on this host

From the NixOS wrapper (do not hardcode store paths):

| Path / setting | Value |
| --- | --- |
| Data | `/var/lib/paperless` |
| Consume | `/var/lib/paperless/consume` |
| Media | `/var/lib/paperless/media` |
| Redis | `unix:///run/redis-paperless/redis.sock` |
| URL | `https://@domain@` |
| Service user | `@user@` |

Drop files into the consume directory to ingest; management commands do the rest.

## Additional resources

- Command details and flags: [reference.md](reference.md)
- Upstream: https://docs.paperless-ngx.com/administration/#management-commands
