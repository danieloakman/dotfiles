#! bun
import { $ } from 'bun';
import meow from 'meow';
import { exit, helpFlag } from './utils/cli';
import { emailClient, type EmailMessage, type EmailSummary } from './utils/email';

/** Default max chars of bodyText in `read -j` (agents); use --full to disable. */
const JSON_BODY_MAX = 4000;

function quoteOperatorValue(value: string): string {
	const trimmed = value.trim();
	if (!trimmed) return '';
	return /\s/.test(trimmed) ? `"${trimmed.replaceAll('"', '')}"` : trimmed;
}

export function buildGmailQuery(options: {
	from?: string;
	to?: string;
	subject?: string;
	after?: string;
	before?: string;
	query?: string;
	keywords?: string;
}): string {
	const parts: string[] = [];
	if (options.from?.trim()) parts.push(`from:${quoteOperatorValue(options.from)}`);
	if (options.to?.trim()) parts.push(`to:${quoteOperatorValue(options.to)}`);
	if (options.subject?.trim()) parts.push(`subject:${quoteOperatorValue(options.subject)}`);
	if (options.after?.trim()) parts.push(`after:${options.after.trim()}`);
	if (options.before?.trim()) parts.push(`before:${options.before.trim()}`);
	if (options.query?.trim()) parts.push(options.query.trim());
	if (options.keywords?.trim()) parts.push(options.keywords.trim());
	return parts.join(' ') || 'in:inbox';
}

function toJsonRead(
	message: EmailMessage,
	{ html = false, full = false }: { html?: boolean; full?: boolean } = {}
) {
	const bodyText =
		full || message.bodyText.length <= JSON_BODY_MAX
			? message.bodyText
			: `${message.bodyText.slice(0, JSON_BODY_MAX)}…`;
	return {
		id: message.id,
		subject: message.subject,
		from: message.from,
		to: message.to,
		date: message.date,
		bodyText,
		...(full || message.bodyText.length <= JSON_BODY_MAX
			? {}
			: { truncated: true, bodyLength: message.bodyText.length }),
		...(html ? { bodyHtml: message.bodyHtml } : {})
	};
}

function toJsonSearchHit(message: EmailSummary) {
	return {
		id: message.id,
		from: message.from,
		subject: message.subject,
		date: message.date
	};
}

function printMessage(message: EmailMessage) {
	console.log(`From: ${message.from}`);
	console.log(`To: ${message.to}`);
	console.log(`Subject: ${message.subject}`);
	console.log(`Date: ${message.date}`);
	console.log(`Id: ${message.id}`);
	console.log();
	if (message.bodyText.trim()) console.log(message.bodyText.trimEnd());
	else if (message.bodyHtml.trim()) console.log('(no plain-text body; HTML only)');
	else console.log('(empty body)');
}

function printList(messages: EmailSummary[]) {
	if (!messages.length) {
		console.log('No messages found.');
		return;
	}
	for (const [i, m] of messages.entries()) {
		console.log(`${i + 1}. ${m.date}  ${m.from}  ${m.subject}`);
		console.log(`   id: ${m.id}`);
		console.log();
	}
}

function pickLine(lines: string): Promise<string> {
	const cmd = process.stdout.isTTY
		? $`echo ${lines} | fzf --no-multi`
		: $`echo ${lines} | rofi -dmenu -p "gmail" -i -no-custom -matching fuzzy`;
	return cmd.text().then((stdout) => stdout.trim());
}

async function pickSummary(messages: EmailSummary[]): Promise<EmailSummary> {
	const lines = messages
		.map((m, i) => `${i + 1}. ${m.date}  ${m.from}  ${m.subject}`)
		.join('\n');
	const selected = await pickLine(lines);
	if (!selected) exit('No message selected');
	const index = Number.parseInt(selected, 10) - 1;
	const message = messages[index];
	if (!message || !selected.startsWith(`${index + 1}.`)) {
		exit(`Couldn't match selection: ${selected}`);
	}
	return message;
}

async function runRead(argv: string[]) {
	const { flags, input, showHelp } = meow(
		`
Usage
  $ gmail-api read <id>

Fetch one Gmail message by id and print headers + body.

Options
  --help, -h     Show help
  --json, -j     Compact JSON (text body only; omits HTML)
  --html, -H     With --json, include bodyHtml
  --full, -F     With --json, do not truncate bodyText (${JSON_BODY_MAX} chars)

Examples
  $ gmail-api read 18c2f1a2b3c4d5e6
  $ gmail-api read 18c2f1a2b3c4d5e6 -j
  $ gmail-api read 18c2f1a2b3c4d5e6 -jF
  $ gmail-api read 18c2f1a2b3c4d5e6 -jH
		`.trimStart(),
		{
			importMeta: import.meta,
			argv,
			flags: {
				...helpFlag,
				json: { type: 'boolean', shortFlag: 'j', default: false },
				html: { type: 'boolean', shortFlag: 'H', default: false },
				full: { type: 'boolean', shortFlag: 'F', default: false }
			}
		}
	);

	if (flags.help) showHelp(0);

	const id = input.join(' ').trim();
	if (!id) {
		showHelp(1);
		exit('Provide a message id');
	}

	try {
		const message = await emailClient.getEmail(id);
		if (flags.json) {
			console.log(
				JSON.stringify(toJsonRead(message, { html: flags.html, full: flags.full }))
			);
		} else printMessage(message);
	} catch (err) {
		exit(`Read failed: ${err instanceof Error ? err.message : err}`);
	}
}

async function runSearch(argv: string[]) {
	const { flags, input, showHelp } = meow(
		`
Usage
  $ gmail-api search [options] [keywords...]

Search Gmail via gws +triage (metadata only; no body fetch).
By default (interactive), pick a result with fzf/rofi then full-read it.
Use --list or --json to skip the picker.
JSON hits are {id,from,subject,date}; use read -j for the body.

Options
  --help, -h           Show help
  --from, -f <addr>    from: operator
  --to, -t <addr>      to: operator
  --subject, -s <text> subject: operator
  --after, -a <date>   after:YYYY/MM/DD
  --before, -b <date>  before:YYYY/MM/DD
  --query, -q <q>      Raw Gmail query fragment (AND with flags)
  --max, -m <n>        Max results (default 20)
  --list, -l           Print human listing only (no picker)
  --json, -j           Compact JSON summaries (no picker)

Examples
  $ gmail-api search invoice -f accounting@example.com -a 2025/01/01
  $ gmail-api search -s "statement" -l
  $ gmail-api search -q 'has:attachment larger:5M' -j -m 5
		`.trimStart(),
		{
			importMeta: import.meta,
			argv,
			flags: {
				...helpFlag,
				from: { type: 'string', shortFlag: 'f', default: '' },
				to: { type: 'string', shortFlag: 't', default: '' },
				subject: { type: 'string', shortFlag: 's', default: '' },
				after: { type: 'string', shortFlag: 'a', default: '' },
				before: { type: 'string', shortFlag: 'b', default: '' },
				query: { type: 'string', shortFlag: 'q', default: '' },
				max: { type: 'number', shortFlag: 'm', default: 20 },
				list: { type: 'boolean', shortFlag: 'l', default: false },
				json: { type: 'boolean', shortFlag: 'j', default: false }
			}
		}
	);

	if (flags.help) showHelp(0);

	const keywords = input.join(' ').trim();
	const query = buildGmailQuery({
		from: flags.from,
		to: flags.to,
		subject: flags.subject,
		after: flags.after,
		before: flags.before,
		query: flags.query,
		keywords
	});

	try {
		const messages = await emailClient.searchSummaries({ query, max: flags.max });
		if (flags.json) {
			console.log(
				JSON.stringify({
					query,
					messages: messages.map(toJsonSearchHit)
				})
			);
			return;
		}
		if (flags.list) {
			console.error(`Query: ${query} (${messages.length} shown)`);
			printList(messages);
			return;
		}
		if (!messages.length) {
			console.error(`Query: ${query}`);
			exit('No messages found.', 1);
		}
		console.error(`Query: ${query} (${messages.length} shown)`);
		const picked = await pickSummary(messages);
		const full = await emailClient.getEmail(picked.id);
		printMessage(full);
	} catch (err) {
		exit(`Search failed: ${err instanceof Error ? err.message : err}`);
	}
}

if (import.meta.main) {
	const cli = meow(
		`
Usage
  $ gmail-api <command> ...

Commands
  search [keywords...]    Search mail (pick result interactively by default)
  read <id>               Print one message by id

Examples
  $ gmail-api search invoice --from boss@example.com
  $ gmail-api search --subject receipt --list
  $ gmail-api read 18c2f1a2b3c4d5e6
  $ gmail-api search --help
		`.trimStart(),
		{
			importMeta: import.meta,
			commands: ['search', 'read'],
			flags: {
				...helpFlag
			}
		}
	);

	if (!cli.command || cli.flags.help) cli.showHelp(0);

	if (cli.command === 'read') await runRead(cli.input);
	else if (cli.command === 'search') await runSearch(cli.input);
}
