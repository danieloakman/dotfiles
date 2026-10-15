#! bun
import { $ } from 'bun';
import meow from 'meow';
import { exit, helpFlag } from './utils/cli';
import { emailClient, type EmailMessage } from './utils/email';

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

function snippet(text: string, max = 120): string {
	const oneLine = text.replace(/\s+/g, ' ').trim();
	if (oneLine.length <= max) return oneLine;
	return `${oneLine.slice(0, max - 1)}…`;
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

function printList(messages: EmailMessage[]) {
	if (!messages.length) {
		console.log('No messages found.');
		return;
	}
	for (const [i, m] of messages.entries()) {
		console.log(`${i + 1}. ${m.date}  ${m.from}  ${m.subject}`);
		console.log(`   id: ${m.id}`);
		const teaser = snippet(m.bodyText);
		if (teaser) console.log(`   ${teaser}`);
		console.log();
	}
}

function pickLine(lines: string): Promise<string> {
	const cmd = process.stdout.isTTY
		? $`echo ${lines} | fzf --no-multi`
		: $`echo ${lines} | rofi -dmenu -p "gmail" -i -no-custom -matching fuzzy`;
	return cmd.text().then((stdout) => stdout.trim());
}

async function pickMessage(messages: EmailMessage[]): Promise<EmailMessage> {
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
  --json         Print JSON instead of human text

Examples
  $ gmail-api read 18c2f1a2b3c4d5e6
		`.trimStart(),
		{
			importMeta: import.meta,
			argv,
			flags: {
				...helpFlag,
				json: { type: 'boolean', default: false }
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
		if (flags.json) console.log(JSON.stringify(message, null, 2));
		else printMessage(message);
	} catch (err) {
		exit(`Read failed: ${err instanceof Error ? err.message : err}`);
	}
}

async function runSearch(argv: string[]) {
	const { flags, input, showHelp } = meow(
		`
Usage
  $ gmail-api search [options] [keywords...]

Search Gmail via gws. Flags compose a Gmail query (AND).
By default (interactive), pick a result with fzf/rofi and print the full message.
Use --list or --json to skip the picker.

Options
  --help, -h           Show help
  --from <addr>        from: operator
  --to <addr>          to: operator
  --subject <text>     subject: operator
  --after <date>       after:YYYY/MM/DD
  --before <date>      before:YYYY/MM/DD
  --query, -q <q>      Raw Gmail query fragment (AND with flags)
  --max <n>            Max results (default 20)
  --list, -l           Print human listing only (no picker)
  --json               Print JSON listing (no picker)

Examples
  $ gmail-api search invoice --from accounting@example.com --after 2025/01/01
  $ gmail-api search --subject "statement" --list
  $ gmail-api search --query 'has:attachment larger:5M' --json
		`.trimStart(),
		{
			importMeta: import.meta,
			argv,
			flags: {
				...helpFlag,
				from: { type: 'string', default: '' },
				to: { type: 'string', default: '' },
				subject: { type: 'string', default: '' },
				after: { type: 'string', default: '' },
				before: { type: 'string', default: '' },
				query: { type: 'string', shortFlag: 'q', default: '' },
				max: { type: 'number', default: 20 },
				list: { type: 'boolean', shortFlag: 'l', default: false },
				json: { type: 'boolean', default: false }
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
		const messages = await emailClient.listEmails({ query, max: flags.max });
		if (flags.json) {
			console.log(JSON.stringify({ query, messages }, null, 2));
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
		const picked = await pickMessage(messages);
		printMessage(picked);
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
