export interface EmailMessage {
	id: string;
	subject: string;
	from: string;
	to: string;
	date: string;
	body: string;
	attachments: unknown[];
}

export interface ListEmailsOptions {
	/** Gmail search query, e.g. `from:boss is:unread`. Defaults to `in:inbox`. */
	query?: string;
	max?: number;
}

export interface EmailClient {
	listEmails(options?: ListEmailsOptions): Promise<EmailMessage[]>;
}

interface GwsError {
	error: { code: number; message: string; reason?: string };
}

interface GmailMessageList {
	messages?: { id: string; threadId: string }[];
}

interface GmailHeader {
	name: string;
	value: string;
}

interface GmailMessage {
	id: string;
	snippet?: string;
	payload?: {
		headers?: GmailHeader[];
	};
}

const GWS = process.env.GWS_BIN ?? 'gws';

function isGwsError(value: unknown): value is GwsError {
	return typeof value === 'object' && value !== null && 'error' in value;
}

async function gwsJson<T>(args: string[]): Promise<T> {
	const proc = Bun.spawn([GWS, ...args], { stdout: 'pipe', stderr: 'pipe' });
	const [stdout, stderr, exitCode] = await Promise.all([
		new Response(proc.stdout).text(),
		new Response(proc.stderr).text(),
		proc.exited
	]);
	const data = JSON.parse(stdout || '{}') as T | GwsError;
	if (exitCode !== 0 || isGwsError(data)) {
		const message = isGwsError(data) ? data.error.message : stderr.trim();
		throw new Error(message || `gws ${args.join(' ')} failed (${exitCode})`);
	}
	return data;
}

function header(message: GmailMessage, name: string): string {
	return (
		message.payload?.headers?.find((h) => h.name.toLowerCase() === name.toLowerCase())?.value ?? ''
	);
}

async function fetchMessage(id: string): Promise<EmailMessage> {
	const message = await gwsJson<GmailMessage>([
		'gmail',
		'users',
		'messages',
		'get',
		'--params',
		JSON.stringify({
			userId: 'me',
			id,
			format: 'metadata',
			metadataHeaders: ['Subject', 'From', 'To', 'Date']
		}),
		'--format',
		'json'
	]);
	return {
		id: message.id,
		subject: header(message, 'Subject'),
		from: header(message, 'From'),
		to: header(message, 'To'),
		date: header(message, 'Date'),
		body: message.snippet ?? '',
		attachments: []
	};
}

export const emailClient: EmailClient = {
	async listEmails({ query = 'in:inbox', max = 50 }: ListEmailsOptions = {}): Promise<EmailMessage[]> {
		const list = await gwsJson<GmailMessageList>([
			'gmail',
			'users',
			'messages',
			'list',
			'--params',
			JSON.stringify({
				userId: 'me',
				q: query,
				maxResults: max
			}),
			'--format',
			'json'
		]);
		if (!list.messages?.length) return [];
		return Promise.all(list.messages.map((message) => fetchMessage(message.id)));
	}
};
