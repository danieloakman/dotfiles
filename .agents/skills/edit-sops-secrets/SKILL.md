---
name: edit-sops-secrets
description: >-
  Edit sops-encrypted secrets/secrets.yaml without a TTY using sops set/unset or
  the bundled helper so the MAC stays valid. Use when adding, removing, or
  changing secrets, editing secrets.yaml, wiring sops-nix keys, or debugging
  missing /run/secrets.
---

# Edit sops secrets

## Hard rule

**Never hand-edit `secrets/secrets.yaml` ciphertext.** Deleting or tweaking `ENC[...]` lines (or the `sops:` MAC block) leaves a stale MAC. `sops-nix` then fails `setupSecrets` and **`/run/secrets` is never created** — often with little obvious signal at edit time.

Interactive humans may use `just edit-secrets` (opens an editor via sops). Agents have no reliable TTY editor — use the workflows below.

## Prerequisites

- Age private key at `~/.config/sops/age/keys.txt` (override with `SOPS_AGE_KEY_FILE`)
- Creation rules in `.sops.yaml` for `secrets/secrets.yaml`
- Declared consumer keys in `modules/services/secrets.linux.nix` (`sops.secrets.*`)

## Preferred tool

Use the helper (wraps `nix shell` + `sops`/`jq`/`yq`, verifies decrypt after mutations):

```bash
.agents/skills/edit-sops-secrets/scripts/sops-secrets.sh <command>
```

Make it executable once if needed: `chmod +x .agents/skills/edit-sops-secrets/scripts/sops-secrets.sh`

## Workflows

### List / read

```bash
./.agents/skills/edit-sops-secrets/scripts/sops-secrets.sh list
./.agents/skills/edit-sops-secrets/scripts/sops-secrets.sh get cursor_api_key
```

Do not paste secret values into chat, commits, or logs unless the user explicitly asks.

### Set or update one key

```bash
./.agents/skills/edit-sops-secrets/scripts/sops-secrets.sh set my_key 'new-value'
# multiline / special chars:
printf '%s' "$value" | ./.agents/skills/edit-sops-secrets/scripts/sops-secrets.sh set-stdin my_key
./.agents/skills/edit-sops-secrets/scripts/sops-secrets.sh set-file gcloud_credentials.json ./creds.json
```

Equivalent raw sops (value **must** be JSON-encoded):

```bash
printf '%s' '"new-value"' | nix shell nixpkgs#sops -c sops set --value-stdin secrets/secrets.yaml '["my_key"]'
```

### Remove one key

```bash
./.agents/skills/edit-sops-secrets/scripts/sops-secrets.sh unset google_client_id
```

Also remove the matching entry from the `secrets` list in `modules/services/secrets.linux.nix` when dropping a consumed secret.

### Bulk replace (multi-key edit)

1. Decrypt to a temp plaintext file **outside git**:
   ```bash
   nix shell nixpkgs#sops -c sops -d secrets/secrets.yaml > /tmp/secrets.plain.yaml
   ```
2. Edit `/tmp/secrets.plain.yaml` (yq, editor, etc.).
3. Write back through sops (updates MAC):
   ```bash
   ./.agents/skills/edit-sops-secrets/scripts/sops-secrets.sh replace /tmp/secrets.plain.yaml
   ```
4. `shred -u /tmp/secrets.plain.yaml` (or `rm` if shred unavailable).

Do **not** `sops decrypt --in-place` on the tracked file and commit plaintext.

### Add a new secret end-to-end

1. `set` / `set-stdin` / `set-file` the key in `secrets/secrets.yaml`
2. Add the name to the `secrets` list in `modules/services/secrets.linux.nix`
3. Reference `config.sops.secrets.<name>.path` from Nix modules
4. Verify (below) then `just check-host`

## Verify (required after every secrets change)

```bash
./.agents/skills/edit-sops-secrets/scripts/sops-secrets.sh verify
# or: nix shell nixpkgs#sops -c sops -d secrets/secrets.yaml >/dev/null
```

If verify fails, **do not commit**. Fix with a proper sops write path; never “fix” the MAC by hand.

Optional: after deploy/switch, confirm `/run/secrets/<key>` exists for keys declared in `secrets.linux.nix`.

## Anti-patterns

| Do not | Why |
| --- | --- |
| Delete `ENC[...]` lines in the encrypted YAML | Stale MAC → `/run/secrets` missing |
| Edit the `sops.mac` / metadata block by hand | Same failure mode |
| Commit decrypted plaintext | Secret leak |
| Change only Nix `sops.secrets` without the YAML key (or vice versa) | Build/runtime mismatch |

## What went wrong before

Commit `e9b79bc` removed `google_client_*` by deleting encrypted lines in `secrets/secrets.yaml`. The MAC was not recomputed, so decryption failed and `/run/secrets` never appeared. Fixed in `df22d06` by rewriting through sops so the MAC matched.
