---
name: paperless-triage
description: >-
  Auto-classify Paperless-ngx documents tagged triage: set title, document
  type, correspondent, and tags via the REST API, then remove the triage tag.
  Use when triaging Paperless inbox/triage docs, classifying scanned documents,
  or when the paperless-triage timer launches cursor-agent.
---

# paperless-triage

Classify and file Paperless documents that still have the **`@tag@`** tag.
Auto-apply metadata. Separate from `paperless-manage` (admin/ops only).

## Auth and base URL

```bash
export PAPERLESS_URL="${PAPERLESS_URL:-https://@domain@}"
# Prefer loopback on the Paperless host:
# export PAPERLESS_URL="http://127.0.0.1:@port@"
TOKEN="$(cat "${PAPERLESS_TOKEN_FILE:-/run/secrets/paperless_api_token}")"
AUTH=(-H "Authorization: Token ${TOKEN}" -H "Accept: application/json")
```

Never print the token. Prefer `http://127.0.0.1:@port@` when running on the
service host.

API details: [reference.md](reference.md).

## Workflow

1. Resolve tag ids for `@tag@` and `@needsReviewTag@` (`GET /api/tags/`).
2. List documents with the triage tag (`GET /api/documents/?tags__id=…`).
3. Once per run, cache taxonomy:
   - `GET /api/tags/`, `/api/correspondents/`, `/api/document_types/`
4. For each document (process the queued batch; if huge, do at least 10 then stop):
   - `GET /api/documents/{id}/` — use `content` (OCR), `title`, existing tags
   - Choose title, document_type, correspondent, and a small tag set
   - **Reuse** existing taxonomy names/ids whenever a close match exists
   - Create a new tag/correspondent/type only when nothing fits; keep names short and consistent
   - Apply via `PATCH /api/documents/{id}/` and/or `POST /api/documents/bulk_edit/`
   - Remove the triage tag (`bulk_edit` `remove_tag` or PATCH tags without it)
   - If uncertain on some fields: set only high-confidence fields; add
     `@needsReviewTag@`; still remove triage once title **or** document_type is set
     (or needs-review was applied)
5. Summarize what changed (ids + new title/type/correspondent/tags). Do not dump full OCR into the summary.

## Guardrails

- Auto-apply is expected; do not ask for confirmation per document.
- Prefer quality over tag count (roughly 1–4 tags besides system tags).
- Do not delete documents. Do not change storage paths in v1.
- Do not invent secrets into titles. Redact account numbers in titles if they appear.
- If the API returns 401/403, stop and report — do not retry with guessed credentials.

## Manual invoke

```bash
# On the Paperless host, with secrets available:
cursor-agent -p --force --trust --workspace "$DOTFILES_DIR" \
  "Follow the paperless-triage skill. Auto-apply. Process triage-tagged documents."
```

The systemd timer only starts this agent when the triage queue count is ≥ `@threshold@`.
Manual runs ignore that gate.
