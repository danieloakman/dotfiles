# Pass

Pass ports the v4 pass-menu into Noctalia v5: search password-store entries, drill into fields, and copy/paste passwords, OTP codes, and metadata.

## Plugin

| Field | Value |
| --- | --- |
| ID | `local/pass` |
| Entries | Launcher provider: `search`; service: `cache` |
| Launcher Prefix | `/pass` |

## Requirements

Install `pass`, `pass-otp`, `gpg`, `wl-copy`, and `wtype` on `PATH`.

Store location matches `pass`: `$PASSWORD_STORE_DIR` when set, otherwise `~/.password-store`.

OTP entries are paths that start with `otp` (typically under `otp/…`) and use `pass otp -c`.

## Usage

Open the launcher with `/pass` (Super+Q in this config).

- Empty query lists every entry.
- Type to filter with v4-style word substring matching (every word must appear in the path).
- Activate a normal entry to drill into `/pass <entry> | `. Optionally filter fields after `|`.
- In drill-in: the password row is masked; other `pass show` lines appear as `value` / `key`. Activate to copy and paste into the focused window (`wtype` Ctrl+V).
- Activate an OTP-marked entry to copy and paste the OTP immediately (no drill-in).

If GPG needs an unlock passphrase during copy, the plugin opens a terminal and re-runs the copy command interactively.

## Settings

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `refresh_interval` | `int` | `60` | Seconds between password-store rescans. Minimum `5`, maximum `3600`. |

## Notes

- Filesystem reads: the cache service indexes non-hidden `*.gpg` paths via async `find` (resolving symlinks first; not a synchronous Luau walk), so it stays under noctalia’s script CPU budget. It does not read decrypted contents for the index.
- Spawned processes: `pass show` for drill-in; `pass -c` / `pass otp -c` for secrets; `wtype` for paste; terminal fallback on GPG unlock failures for copy.
- Clipboard/privacy: secrets go through `pass`/`pass-otp` clipboard handling; field values use `noctalia.copyToClipboard`. The plugin state stores paths/titles and the current drill-in field cache only while that entry is open.
- Network: none.
- Writes: none by the plugin itself.
