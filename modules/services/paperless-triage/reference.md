# paperless-triage API reference

Base: `$PAPERLESS_URL` (e.g. `http://127.0.0.1:28981`).  
Auth header: `Authorization: Token $TOKEN`.

## List / filter

```bash
# Tag by exact name
curl -sf "${AUTH[@]}" "$PAPERLESS_URL/api/tags/?name=triage"

# Documents with a tag (count in .count)
curl -sf "${AUTH[@]}" "$PAPERLESS_URL/api/documents/?tags__id=TAG_ID&page_size=25"

# Full document including OCR text
curl -sf "${AUTH[@]}" "$PAPERLESS_URL/api/documents/DOC_ID/"
```

Paginate with `.next` when needed.

## Taxonomy

```bash
curl -sf "${AUTH[@]}" "$PAPERLESS_URL/api/tags/?page_size=100"
curl -sf "${AUTH[@]}" "$PAPERLESS_URL/api/correspondents/?page_size=100"
curl -sf "${AUTH[@]}" "$PAPERLESS_URL/api/document_types/?page_size=100"
```

Create when required:

```bash
curl -sf "${AUTH[@]}" -H "Content-Type: application/json" \
  -d '{"name":"Tax"}' "$PAPERLESS_URL/api/tags/"
# same shape for /api/correspondents/ and /api/document_types/
```

## Update one document

`PATCH` replaces the **entire** `tags` list when `tags` is sent — include every
tag id you want to keep (minus triage, plus new ones).

```bash
curl -sf "${AUTH[@]}" -X PATCH -H "Content-Type: application/json" \
  -d '{"title":"…","correspondent":1,"document_type":2,"tags":[3,4]}' \
  "$PAPERLESS_URL/api/documents/DOC_ID/"
```

## Bulk edit (safer for tag add/remove)

```bash
curl -sf "${AUTH[@]}" -X POST -H "Content-Type: application/json" \
  -d '{"documents":[DOC_ID],"method":"remove_tag","parameters":{"tag":TRIAGE_ID}}' \
  "$PAPERLESS_URL/api/documents/bulk_edit/"

# methods: add_tag, remove_tag, modify_tags, set_correspondent, set_document_type, …
```

`modify_tags` takes `add_tags` / `remove_tags` id lists.

## One-time Paperless setup

1. Create API token: Paperless UI → profile / API tokens → copy token into sops
   key `paperless_api_token` (see edit-sops-secrets skill).
2. Create tags named `triage` and `needs-review` (names must match module options).
3. Workflow: **Document Added** → Assignment action → add tag `triage`.
   Leave built-in matching enabled; triage is an extra queue for the agent.
