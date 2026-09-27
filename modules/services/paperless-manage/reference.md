# paperless-manage command reference

All commands: `paperless-manage <name> …` or `paperless-manage help <name>`.

## document_exporter

```bash
paperless-manage document_exporter TARGET [options]
```

Writes documents, thumbnails, and `manifest.json` to `TARGET`. If `TARGET`
already has a previous export, only changed/added files are written unless
checksum comparison is forced.

| Flag | Effect |
| --- | --- |
| `-c` / `--compare-checksums` | Detect changes via checksum (slower) |
| `-cj` / `--compare-json` | Skip updating unchanged JSON/manifest |
| `-d` / `--delete` | Remove files in TARGET that are not part of this export |
| `-f` / `--use-filename-format` | Use `PAPERLESS_FILENAME_FORMAT` for names |
| `-na` / `--no-archive` | Skip archive PDFs |
| `-nt` / `--no-thumbnail` | Skip thumbnails |
| `-p` / `--use-folder-prefix` | Split into `archive`/`originals`/`thumbnails`/`json` |
| `-sm` / `--split-manifest` | Per-document JSON + main manifest |
| `-z` / `--zip` | Zip the export |
| `-zn` / `--zip-name` | Zip filename |
| `--data-only` | Database/metadata only (no media files) |
| `--no-progress-bar` | Quiet (cron/scripts) |
| `--passphrase` | Encrypt sensitive export fields (required again on import) |

**Warning:** `--delete` removes files under `TARGET` that are not in the current
export. Only use with an dedicated export directory.

## document_importer

```bash
paperless-manage document_importer SOURCE [--data-only] [--no-progress-bar] [--passphrase …]
```

`SOURCE` is an export directory or zip from `document_exporter`.

Run against an empty Paperless install (empty DB and media), unless `--data-only`
(empty DB only). Match Paperless versions when possible.

## document_retagger

```bash
paperless-manage document_retagger [-c] [-T] [-t] [-s] [-i] [--id-range A B] [--use-first] [-f]
```

Re-run matching rules on existing documents. With no `-c`/`-T`/`-t`/`-s`, does
nothing.

| Flag | Effect |
| --- | --- |
| `-c` | Correspondents |
| `-T` | Tags |
| `-t` | Document types |
| `-s` | Storage paths |
| `-i` | Inbox-tagged docs only |
| `--id-range A B` | Limit to document id range |
| `--use-first` | If multiple matches, take the first (types/correspondents) |
| `-f` | Overwrite existing assignments (for tags: also remove non-matches) |

## document_index

```bash
paperless-manage document_index reindex
paperless-manage document_index optimize
```

- `reindex` — rebuild search index from scratch (slow on large archives)
- `optimize` — tune index / autocompletion (scheduler usually runs this)

## document_sanity_checker

```bash
paperless-manage document_sanity_checker
```

Reports orphan media files, missing/corrupt originals or archives, bad
permissions, empty content, missing thumbnails.

## document_create_classifier

```bash
paperless-manage document_create_classifier
```

Retrain the automatic matching neural net after data/rule changes.

## document_thumbnails

```bash
paperless-manage document_thumbnails [--document ID] [--processes N]
```

Default process count is ~¼ of CPUs.

## document_archiver

```bash
paperless-manage document_archiver [--overwrite] [--document ID]
```

Create PDF/A archive versions. Skips docs that already have an archive unless
`--overwrite`. Can be very slow with OCR redo modes; safe to interrupt and
resume.

## document_renamer

```bash
paperless-manage document_renamer
```

Move/rename all files after changing filename format. Backup first; will not
overwrite or delete, but still treat as high-impact.

## mail_fetcher

```bash
paperless-manage mail_fetcher
```

Pull mail accounts/rules immediately (normally on a timer).

## invalidate_cachalot

```bash
paperless-manage invalidate_cachalot
```

Clear DB read cache after out-of-band SQL/restores (only if cachalot is enabled).

## Django / ops

Useful built-ins when troubleshooting:

```bash
paperless-manage showmigrations
paperless-manage migrate
paperless-manage createsuperuser
paperless-manage shell
paperless-manage check
```

Prefer `migrate` only when you understand why migrations are pending; NixOS
service start usually applies them.
