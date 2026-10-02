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

## Taxonomy policy

Live lists from `GET /api/tags/`, `/api/correspondents/`, and
`/api/document_types/` are the **source of truth**. This section is policy
only — do not treat any example name below as an exclusive allow-list.

| Field | Means | Prefer | Avoid |
| --- | --- | --- | --- |
| **Correspondent** | Who issued or authored the document (org or professional) | Stable org/person name already in the API; close alias → reuse that id | Personal inbox/forwarder emails; clinic mailbox addresses when an org name exists |
| **Document type** | Form of the document (how it would be named in a filing cabinet) | Closest existing type (receipt vs invoice vs letter vs report vs quote, etc.) | Forcing everything into one catch-all type |
| **Tags** | Topic / facet for filtering (life area, program, subject) | Small set of topical tags already in the API | Putting the issuer in tags when it belongs in correspondent |
| **Title** | Short human label for search and lists | Issuer + what + date when useful | `Fw:`/`Fwd:`, scanner filenames, UUIDs, raw mail subjects |

**Reuse vs create:** Reuse on close match (case, spacing, abbreviation, email↔org
alias). Create only when nothing fits **and** the same kind of document is
likely to recur. Keep new names short, Title Case or consistent with neighbors.

**System tags (config-coupled):** `@tag@` = inbox queue (remove when done);
`@needsReviewTag@` = uncertain fields. Do not use these as topical tags.

**Uncertainty:** Set only high-confidence fields; add `@needsReviewTag@`; still
clear `@tag@` once title **or** document_type is set (or needs-review was
applied).

## Workflow

1. Resolve tag ids for `@tag@` and `@needsReviewTag@` (`GET /api/tags/`).
2. List documents with the triage tag (`GET /api/documents/?tags__id=…`).
3. Once per run, cache taxonomy from the API (source of truth):
   - `GET /api/tags/`, `/api/correspondents/`, `/api/document_types/`
4. For each document (process the queued batch; if huge, do at least 10 then stop):
   - `GET /api/documents/{id}/` — use `content` (OCR), `title`, existing tags
   - Choose title, document_type, correspondent, and tags using **Taxonomy policy**
   - Apply via `PATCH /api/documents/{id}/` and/or `POST /api/documents/bulk_edit/`
   - Remove the `@tag@` tag (`bulk_edit` `remove_tag` or PATCH tags without it)
5. Summarize what changed (ids + new title/type/correspondent/tags). Do not dump full OCR into the summary.

## Guardrails

- Auto-apply is expected; do not ask for confirmation per document.
- Prefer quality over tag count (roughly 1–4 topical tags besides system tags).
- Do not delete documents. Do not change storage paths in v1.
- Do not invent secrets into titles. Redact account numbers in titles if they appear.
- If the API returns 401/403, stop and report — do not retry with guessed credentials.

## Manual invoke

```bash
# On the Paperless host, with secrets available:
cursor-agent -p --force --trust --workspace "$DOTFILES_DIR" \
  "Follow the paperless-triage skill. Auto-apply. Process triage-tagged documents."
```

The systemd timer only starts this agent when the triage queue count is ≥ `@threshold@`,
or when the oldest triage document (`added`) is older than `@maxAge@`.
Manual runs ignore that gate.
