# Web Search

Local port of the v4 web-search launcher provider: search the web from Noctalia with live autocomplete suggestions.

## Plugin

| Field | Value |
| --- | --- |
| ID | `local/web-search` |
| Entry | Launcher provider: `search` |
| Launcher Prefix | `/web` |

## Requirements

`xdg-utils` on `PATH` (for `xdg-open`). Network access for suggestions and opening search pages.

## Usage

```text
/web chocolate cake recipe
/web github.com/noctalia-dev
/web localhost:3000
```

Super+S opens the launcher on `/web`. Unprefixed launcher search does not include this provider.

Activate a result to open it in the default browser.

## Settings

| Setting | Type | Default | Description |
| --- | --- | --- | --- |
| `search_engine` | select | `Google` | Google, DuckDuckGo, Bing, Brave, or Yandex |
| `direct_url` | bool | `true` | Detect URLs / IPs / localhost and open directly |
| `show_suggestions` | bool | `true` | Fetch live autocomplete suggestions |
| `max_results` | int | `5` | Suggestion count (1–10) |
