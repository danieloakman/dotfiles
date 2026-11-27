# agent-usage spike

`src/agent-usage.ts` prints current AI coding usage for Claude Code and Cursor.
JSON by default, `--table` for humans, optional provider args (`agent-usage cursor`).
Read-only; tokens are read from the tools' own on-disk creds, kept in memory, sent only to the provider, never printed.
Tokens are NOT refreshed (refresh tokens rotate; writing/using them could log the real client out). Expired token => clear error.

## Claude (Pro subscription): works

- Creds: `~/.claude/.credentials.json` -> `claudeAiOauth.accessToken` (scope `user:profile`/`user:inference`).
- `GET https://api.anthropic.com/api/oauth/usage` with `Authorization: Bearer`, `anthropic-beta: oauth-2025-04-20`.
  - `five_hour` / `seven_day` (+ `seven_day_opus`/`sonnet` when present): `utilization` (% used), `resets_at`.
  - `extra_usage`: enabled, monthly_limit, used_credits, currency (overage spend).
  - `limits[]`: normalised list (kind, group, percent, severity, resets_at, is_active).
  - Many obfuscated/null experimental keys; ignored. Undocumented API, can change.
- `GET https://api.anthropic.com/api/oauth/profile`: plan type, subscription status.
- Local JSONL (`~/.claude/projects/**/*.jsonl`, ccusage-style): token totals today / 7d, deduped by message.id+requestId. Tokens only (no $ pricing; meaningless on a subscription).
- Not available: absolute message counts / token caps (API gives % only). Anthropic Admin API (`/v1/organizations/usage_report`) needs an org admin key (`sk-ant-admin...`), not applicable to a personal Pro plan.
- Token TTL is hours; Claude Code refreshes it when run. Not refreshed here.

## Cursor: works

- Creds: `~/.config/cursor/auth.json` (cursor-agent) `accessToken` (JWT, short TTL ~10min, kept fresh by cursor-agent/app). `apiKey` field is NOT accepted by these endpoints.
- Connect-JSON RPC at `https://api2.cursor.sh/aiserver.v1.DashboardService/<Method>` (POST `{}`, `Authorization: Bearer`, `Connect-Protocol-Version: 1`):
  - `GetCurrentPeriodUsage`: billingCycleStart/End (ms), `planUsage.totalPercentUsed`/`autoPercentUsed`, `spendLimitUsage`, displayMessage.
  - `GetPlanInfo`: planName, `includedUsagePeriod` (this plan is WEEKLY), `includedUsageResetsAt`, monthly billingCycleEnd.
  - `GetUsageLimitStatusAndActiveGrants`: on-demand limit bounds/adjustability.
  - `GetHardLimit`, `GetMe`, `GetFilteredUsageEvents` (per-request events with tokens + chargedCents; not used, could build $ spend / per-model breakdown).
- `GET https://api2.cursor.sh/auth/full_stripe_profile`: membership, subscription status.
- Doesn't work: the cursor.com web endpoints (`/api/usage-summary`, `/api/usage`, `/api/dashboard/*`) 401/307 with the `WorkosCursorSessionToken=<id>::<jwt>` cookie built from this token (that needs the browser session JWT of type `web`, not cli `api_key_token`). Not needed given api2.
- Gap: on-demand dollars spent are not in `GetCurrentPeriodUsage` for this account (`spendLimitUsage` only has `limitType`); would need summing `chargedCents` from `GetFilteredUsageEvents` where usageType is on-demand.
- Token-refresh: `auth.json` refreshToken could mint a new access token at the WorkOS/api2 oauth endpoint; deliberately not implemented (rotation risk).

## Ideas / next

- Add providers (Codex, Copilot, Gemini; endpoints not yet researched) via the same `fns` map.
- Cursor $ spend by summing `GetFilteredUsageEvents` for the billing cycle.
- Ship as agent skill / statusline source with caching (usage endpoints are rate limited; cache 60s).
