#! bun
import { join, resolve } from 'node:path';
import { $ } from 'bun';
import meow from 'meow';
import { exit, helpFlag } from './utils/cli';
import {
	emailClient,
	resolveDownloadPath,
	type EmailAttachment,
	type EmailMessage,
	type EmailSummary
} from './utils/email';

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

function toJsonAttachment(a: EmailAttachment) {
	return {
		id: a.id,
		filename: a.filename,
		mimeType: a.mimeType,
		size: a.size,
		inline: a.inline
	};
}

function printAttachments(attachments: EmailAttachment[]) {
	if (!attachments.length) {
		console.log('No attachments.');
		return;
	}
	for (const [i, a] of attachments.entries()) {
		const kind = a.inline ? 'inline' : 'attachment';
		console.log(`${i + 1}. ${a.filename}  (${a.mimeType}, ${a.size} bytes, ${kind})`);
		console.log(`   id: ${a.id}`);
		console.log();
	}
}

function matchAttachment(
	attachments: EmailAttachment[],
	selector: string
): EmailAttachment {
	const byId = attachments.find((a) => a.id === selector);
	if (byId) return byId;
	const exact = attachments.filter((a) => a.filename === selector);
	if (exact.length === 1) return exact[0]!;
	if (exact.length > 1) {
		exit(`Multiple attachments named "${selector}"; pass the attachment id instead`);
	}
	const loose = attachments.filter((a) =>
		a.filename.toLowerCase().includes(selector.toLowerCase())
	);
	if (loose.length === 1) return loose[0]!;
	if (loose.length > 1) {
		exit(
			`Ambiguous attachment "${selector}" matched: ${loose.map((a) => a.filename).join(', ')}`
		);
	}
	exit(`No attachment matching "${selector}"`);
}

async function runAttachments(argv: string[]) {
	const { flags, input, showHelp } = meow(
		`
Usage
  $ gmail-api attachments <message-id>

List attachment metadata for a message (id, filename, mimeType, size, inline).
Does not download bytes — use download for that.

Options
  --help, -h     Show help
  --json, -j     Compact JSON array

Examples
  $ gmail-api attachments 18c2f1a2b3c4d5e6 -j
		`.trimStart(),
		{
			importMeta: import.meta,
			argv,
			flags: {
				...helpFlag,
				json: { type: 'boolean', shortFlag: 'j', default: false }
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
		const attachments = await emailClient.listAttachments(id);
		if (flags.json) {
			console.log(
				JSON.stringify({
					id,
					attachments: attachments.map(toJsonAttachment)
				})
			);
		} else printAttachments(attachments);
	} catch (err) {
		exit(`Attachments failed: ${err instanceof Error ? err.message : err}`);
	}
}

async function runDownload(argv: string[]) {
	const { flags, input, showHelp } = meow(
		`
Usage
  $ gmail-api download <message-id> [filename-or-attachment-id]

Download one attachment (or all with --all) to disk.
Omit the selector when the message has exactly one attachment.
Default destination is ./<filename> (use -o for another path or directory/).

Options
  --help, -h           Show help
  --all, -a            Download every attachment
  --output, -o <path>  File path (single) or directory/ (trailing slash or --all)
  --json, -j           Compact JSON result(s)

Examples
  $ gmail-api download 18c2f1a2b3c4d5e6 invoice.pdf
  $ gmail-api download 18c2f1a2b3c4d5e6 -a -o ./inbox/
  $ gmail-api download 18c2f1a2b3c4d5e6 -j
		`.trimStart(),
		{
			importMeta: import.meta,
			argv,
			flags: {
				...helpFlag,
				all: { type: 'boolean', shortFlag: 'a', default: false },
				output: { type: 'string', shortFlag: 'o', default: '' },
				json: { type: 'boolean', shortFlag: 'j', default: false }
			}
		}
	);

	if (flags.help) showHelp(0);

	const messageId = input[0]?.trim() ?? '';
	const selector = input.slice(1).join(' ').trim();
	if (!messageId) {
		showHelp(1);
		exit('Provide a message id');
	}
	if (flags.all && selector) {
		exit('Pass either --all or a filename/id, not both');
	}

	try {
		const attachments = await emailClient.listAttachments(messageId);
		if (!attachments.length) exit('No attachments on that message', 1);

		const chosen = flags.all
			? attachments
			: [
					selector
						? matchAttachment(attachments, selector)
						: attachments.length === 1
							? attachments[0]!
							: exit(
									`Message has ${attachments.length} attachments; pass a filename/id or --all`
								)
				];

		const outFlag = flags.output.trim();
		const results: { filename: string; path: string; size: number; id: string }[] = [];

		for (const att of chosen) {
			const dest = (() => {
				if (!outFlag) return resolve(att.filename);
				if (flags.all || outFlag.endsWith('/') || outFlag.endsWith('\\')) {
					return resolveDownloadPath(
						outFlag.endsWith('/') || outFlag.endsWith('\\') ? outFlag : `${outFlag}/`,
						att.filename
					);
				}
				if (chosen.length === 1) return resolve(outFlag);
				return join(resolve(outFlag), att.filename);
			})();

			const saved = await emailClient.downloadAttachment({
				messageId,
				attachmentId: att.id,
				path: dest
			});
			results.push({
				filename: att.filename,
				path: saved.path,
				size: saved.size,
				id: att.id
			});
		}

		if (flags.json) {
			console.log(JSON.stringify({ id: messageId, downloaded: results }));
		} else {
			for (const r of results) {
				console.log(`Saved ${r.filename} → ${r.path} (${r.size} bytes)`);
			}
		}
	} catch (err) {
		exit(`Download failed: ${err instanceof Error ? err.message : err}`);
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
  search [keywords...]         Search mail (pick result interactively by default)
  read <id>                    Print one message by id
  attachments <id>             List attachment metadata for a message
  download <id> [name-or-id]   Download attachment(s) to disk

Examples
  $ gmail-api search invoice --from boss@example.com
  $ gmail-api search --subject receipt --list
  $ gmail-api read 18c2f1a2b3c4d5e6
  $ gmail-api attachments 18c2f1a2b3c4d5e6 -j
  $ gmail-api download 18c2f1a2b3c4d5e6 invoice.pdf
  $ gmail-api search --help
		`.trimStart(),
		{
			importMeta: import.meta,
			commands: ['search', 'read', 'attachments', 'download'],
			flags: {
				...helpFlag
			}
		}
	);

	if (!cli.command || cli.flags.help) cli.showHelp(0);

	if (cli.command === 'read') await runRead(cli.input);
	else if (cli.command === 'search') await runSearch(cli.input);
	else if (cli.command === 'attachments') await runAttachments(cli.input);
	else if (cli.command === 'download') await runDownload(cli.input);
}
