import { createReadStream, existsSync, readFileSync, readdirSync, statSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { createInterface } from 'node:readline';
import meow from 'meow';
import { exit, helpFlag } from './utils/cli';

// Read-only: tokens are read from the providers' own on-disk credentials, held in
// memory, sent only to the provider's own API, and never printed or written back.
// Tokens are NOT refreshed here (refresh tokens rotate and would log the CLI out).

const PROVIDERS = ['claude', 'cursor'] as const;
type Provider = (typeof PROVIDERS)[number];

interface Window {
	name: string;
	percentUsed: number | null;
	resetsAt: string | null;
}

interface ProviderUsage {
	provider: Provider;
	ok: boolean;
	error?: string;
	plan?: string | null;
	windows?: Window[];
	/** Dollar/credit spend beyond the plan (Claude extra usage, Cursor on-demand). */
	overage?: Record<string, unknown> | null;
	/** Provider-specific extras (billing cycle, local logs, ...). */
	extra?: Record<string, unknown>;
}

const msToIso = (ms: unknown) => {
	const n = Number(ms);
	return Number.isFinite(n) && n > 0 ? new Date(n).toISOString() : null;
};

async function getJson(url: string, init: RequestInit): Promise<any> {
	const res = await fetch(url, { ...init, signal: AbortSignal.timeout(15_000) });
	if (!res.ok) throw new Error(`${new URL(url).pathname} -> HTTP ${res.status}`);
	return res.json();
}

// ---------- Claude ----------

const CLAUDE_DIR = join(process.env.CLAUDE_CONFIG_DIR ?? join(homedir(), '.claude'));

/** Token totals from local Claude Code JSONL logs (ccusage-style), deduped by message+request id. */
async function claudeLocalTokens() {
	const root = join(CLAUDE_DIR, 'projects');
	if (!existsSync(root)) return null;
	const now = Date.now();
	const cutoff = now - 7 * 86_400_000;
	const startOfDay = new Date().setHours(0, 0, 0, 0);
	const mk = () => ({ input: 0, output: 0, cacheWrite: 0, cacheRead: 0, messages: 0 });
	const today = mk();
	const week = mk();
	const seen = new Set<string>();
	const files: string[] = [];
	const walk = (dir: string) => {
		for (const e of readdirSync(dir, { withFileTypes: true })) {
			const p = join(dir, e.name);
			if (e.isDirectory()) walk(p);
			else if (e.name.endsWith('.jsonl') && statSync(p).mtimeMs >= cutoff) files.push(p);
		}
	};
	walk(root);
	for (const f of files) {
		const rl = createInterface({ input: createReadStream(f), crlfDelay: Infinity });
		for await (const line of rl) {
			if (!line.includes('"usage"')) continue;
			let o: any;
			try {
				o = JSON.parse(line);
			} catch {
				continue;
			}
			const u = o?.message?.usage;
			const ts = Date.parse(o?.timestamp);
			if (!u || !(ts >= cutoff)) continue;
			const key = `${o.message.id}:${o.requestId}`;
			if (seen.has(key)) continue;
			seen.add(key);
			for (const b of ts >= startOfDay ? [week, today] : [week]) {
				b.input += u.input_tokens ?? 0;
				b.output += u.output_tokens ?? 0;
				b.cacheWrite += u.cache_creation_input_tokens ?? 0;
				b.cacheRead += u.cache_read_input_tokens ?? 0;
				b.messages++;
			}
		}
	}
	return { today, last7d: week };
}

async function claude(): Promise<ProviderUsage> {
	const credPath = join(CLAUDE_DIR, '.credentials.json');
	if (!existsSync(credPath)) return { provider: 'claude', ok: false, error: `no ${credPath}` };
	const oauth = JSON.parse(readFileSync(credPath, 'utf8')).claudeAiOauth;
	if (!oauth?.accessToken)
		return { provider: 'claude', ok: false, error: 'no claudeAiOauth token' };
	if (oauth.expiresAt && oauth.expiresAt < Date.now())
		return {
			provider: 'claude',
			ok: false,
			error: 'access token expired; run `claude` once to refresh'
		};
	const headers = {
		Authorization: `Bearer ${oauth.accessToken}`,
		'anthropic-beta': 'oauth-2025-04-20',
		'User-Agent': 'agent-usage/0.1'
	};
	try {
		const [usage, profile, local] = await Promise.all([
			getJson('https://api.anthropic.com/api/oauth/usage', { headers }),
			getJson('https://api.anthropic.com/api/oauth/profile', { headers }).catch(() => null),
			claudeLocalTokens().catch(() => null)
		]);
		const labels: Record<string, string> = {
			five_hour: 'session (5h)',
			seven_day: 'weekly (all models)',
			seven_day_opus: 'weekly (opus)',
			seven_day_sonnet: 'weekly (sonnet)',
			seven_day_oauth_apps: 'weekly (oauth apps)'
		};
		const windows: Window[] = Object.entries(labels)
			.filter(([k]) => usage[k])
			.map(([k, name]) => ({
				name,
				percentUsed: usage[k].utilization ?? null,
				resetsAt: usage[k].resets_at ?? null
			}));
		const ex = usage.extra_usage;
		return {
			provider: 'claude',
			ok: true,
			plan: profile?.organization?.organization_type ?? oauth.subscriptionType ?? null,
			windows,
			overage: ex
				? {
						enabled: ex.is_enabled,
						monthlyLimit: ex.monthly_limit,
						used: ex.used_credits,
						utilization: ex.utilization,
						currency: ex.currency,
						spendLimitReached: ex.spend_limit_reached
					}
				: null,
			extra: {
				limits: usage.limits ?? null,
				subscriptionStatus: profile?.organization?.subscription_status ?? null,
				rateLimitTier: oauth.rateLimitTier ?? null,
				localTokens: local
			}
		};
	} catch (err) {
		return {
			provider: 'claude',
			ok: false,
			error: err instanceof Error ? err.message : String(err)
		};
	}
}

// ---------- Cursor ----------

/** Same sources as the cursor-agent wrapper (modules/programs/cursor.nix): env, sops secret, then pass. */
function cursorApiKey(): string | null {
	const env = process.env.CURSOR_API_KEY?.trim();
	if (env) return env;
	const sops = '/run/secrets/cursor_api_key';
	try {
		const k = readFileSync(sops, 'utf8').trim();
		if (k) return k;
	} catch {}
	const r = Bun.spawnSync(['pass', 'api_keys/personal/cursor_ai'], { stderr: 'ignore' });
	return r.exitCode === 0 ? r.stdout.toString().trim() || null : null;
}

async function cursor(): Promise<ProviderUsage> {
	const apiKey = cursorApiKey();
	if (!apiKey)
		return {
			provider: 'cursor',
			ok: false,
			error:
				'no Cursor API key (CURSOR_API_KEY, /run/secrets/cursor_api_key, or pass api_keys/personal/cursor_ai)'
		};
	// Same exchange cursor-agent does for --api-key; the result is held in memory only.
	let accessToken: string;
	try {
		const ex = await getJson('https://api2.cursor.sh/auth/exchange_user_api_key', {
			method: 'POST',
			headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
			body: '{}'
		});
		accessToken = ex.accessToken;
		if (!accessToken) throw new Error('no accessToken in exchange response');
	} catch (err) {
		return {
			provider: 'cursor',
			ok: false,
			error: `API key exchange failed: ${err instanceof Error ? err.message : err}`
		};
	}
	const headers = {
		Authorization: `Bearer ${accessToken}`,
		'Content-Type': 'application/json',
		'Connect-Protocol-Version': '1'
	};
	const rpc = (m: string) =>
		getJson(`https://api2.cursor.sh/aiserver.v1.DashboardService/${m}`, {
			method: 'POST',
			headers,
			body: '{}'
		});
	try {
		const [period, plan, limits, hard, stripe] = await Promise.all([
			rpc('GetCurrentPeriodUsage'),
			rpc('GetPlanInfo').catch(() => null),
			rpc('GetUsageLimitStatusAndActiveGrants').catch(() => null),
			rpc('GetHardLimit').catch(() => null),
			getJson('https://api2.cursor.sh/auth/full_stripe_profile', { headers }).catch(() => null)
		]);
		const p = period.planUsage ?? {};
		const windows: Window[] = [
			{
				name: 'included usage (plan period)',
				percentUsed: p.totalPercentUsed ?? null,
				resetsAt: msToIso(plan?.planInfo?.includedUsageResetsAt ?? period.billingCycleEnd)
			}
		];
		if (p.autoPercentUsed != null && p.autoPercentUsed !== p.totalPercentUsed)
			windows.push({
				name: 'auto/composer',
				percentUsed: p.autoPercentUsed,
				resetsAt: windows[0]!.resetsAt
			});
		if (p.apiPercentUsed != null)
			windows.push({
				name: 'named models (api)',
				percentUsed: p.apiPercentUsed,
				resetsAt: windows[0]!.resetsAt
			});
		const lim = limits?.usageLimitPolicyStatus;
		return {
			provider: 'cursor',
			ok: true,
			plan: plan?.planInfo?.planName ?? stripe?.membershipType ?? null,
			windows,
			overage: {
				spendLimit: period.spendLimitUsage ?? null,
				onDemandAdjustable: lim?.canAdjustOnDemand ?? null,
				onDemandLimitCents: {
					min: lim?.onDemandMinCents,
					max: lim?.onDemandMaxCents,
					recommended: lim?.recommendedOnDemandLimitCents
				},
				hardLimit: hard?.hardLimit ?? null
			},
			extra: {
				billingCycleStart: msToIso(period.billingCycleStart),
				billingCycleEnd: msToIso(period.billingCycleEnd),
				includedUsagePeriod: plan?.planInfo?.includedUsagePeriod ?? null,
				planBillingCycleEnd: msToIso(plan?.planInfo?.billingCycleEnd),
				message: period.displayMessage ?? null,
				subscriptionStatus: stripe?.subscriptionStatus ?? null
			}
		};
	} catch (err) {
		return {
			provider: 'cursor',
			ok: false,
			error: err instanceof Error ? err.message : String(err)
		};
	}
}

// ---------- output ----------

function until(iso: string | null) {
	if (!iso) return '';
	const mins = Math.round((Date.parse(iso) - Date.now()) / 60_000);
	if (mins < 0) return ' (passed)';
	const d = Math.floor(mins / 1440);
	const h = Math.floor((mins % 1440) / 60);
	return ` (in ${d ? `${d}d ` : ''}${h ? `${h}h ` : ''}${mins % 60}m)`;
}

function printTable(results: ProviderUsage[]) {
	for (const r of results) {
		console.log(`${r.provider}${r.plan ? `  [${r.plan}]` : ''}`);
		if (!r.ok) {
			console.log(`  error: ${r.error}\n`);
			continue;
		}
		for (const w of r.windows ?? []) {
			const pct = w.percentUsed == null ? '?' : `${w.percentUsed.toFixed(1)}%`;
			console.log(
				`  ${w.name.padEnd(30)} ${pct.padStart(6)} used   resets ${w.resetsAt ?? '?'}${until(w.resetsAt)}`
			);
		}
		if (r.overage) console.log(`  overage: ${JSON.stringify(r.overage)}`);
		for (const [k, v] of Object.entries(r.extra ?? {})) {
			if (k === 'limits' || v == null) continue;
			console.log(`  ${k}: ${typeof v === 'object' ? JSON.stringify(v) : v}`);
		}
		console.log();
	}
}

const cli = meow(
	`
Usage
  $ agent-usage [provider...]

Print current AI coding usage (read-only). Providers: ${PROVIDERS.join(', ')} (default: all).
JSON on stdout by default; use --table for human output.

Options
  --help, -h     Show help
  --table, -t    Human-readable output instead of JSON

Examples
  $ agent-usage
  $ agent-usage cursor --table
	`.trimStart(),
	{
		importMeta: import.meta,
		flags: { ...helpFlag, table: { type: 'boolean', shortFlag: 't', default: false } }
	}
);

if (cli.flags.help) cli.showHelp(0);

const wanted = (cli.input.length ? cli.input : [...PROVIDERS]) as Provider[];
for (const w of wanted)
	if (!PROVIDERS.includes(w)) exit(`Unknown provider '${w}' (have: ${PROVIDERS.join(', ')})`, 2);

const fns: Record<Provider, () => Promise<ProviderUsage>> = { claude, cursor };
const results = await Promise.all(wanted.map((p) => fns[p]()));
if (cli.flags.table) printTable(results);
else console.log(JSON.stringify(results, null, 2));
if (results.every((r) => !r.ok)) process.exit(1);
