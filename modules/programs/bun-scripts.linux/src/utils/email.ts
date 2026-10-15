import { z } from 'zod';
import { gwsJson } from './gws';

export interface EmailMessage {
	id: string;
	subject: string;
	from: string;
	to: string;
	date: string;
	bodyText: string;
	bodyHtml: string;
	attachments: unknown[];
}

/** Metadata-only hit from `gws gmail +triage` (no body fetch). */
export interface EmailSummary {
	id: string;
	subject: string;
	from: string;
	date: string;
}

export interface EmailClient {
	/** Lightweight search via `gws gmail +triage` (headers only, no body). */
	searchSummaries(options?: {
		/** Gmail search query, e.g. `from:boss is:unread`. Defaults to `in:inbox`. */
		query?: string;
		max?: number;
	}): Promise<EmailSummary[]>;
	/** Full-read each hit (N+1). Prefer searchSummaries + getEmail for agent use. */
	listEmails(options?: {
		query?: string;
		max?: number;
	}): Promise<EmailMessage[]>;
	getEmail(id: string): Promise<EmailMessage>;
	markAsRead(id: string): Promise<void>;
	markAsUnread(id: string): Promise<void>;
}

const gmailMessageListSchema = z.object({
	messages: z.array(z.object({ id: z.string(), threadId: z.string() })).optional()
});

const gmailTriageSchema = z.object({
	messages: z
		.array(
			z.object({
				id: z.string(),
				from: z.string(),
				subject: z.string().nullable().optional(),
				date: z.string().nullable().optional()
			})
		)
		.optional()
});

const gmailAddressSchema = z.object({
	name: z.string().nullable().optional(),
	email: z.string()
});

const gmailReadSchema = z.object({
	from: gmailAddressSchema,
	to: z.array(gmailAddressSchema),
	subject: z.string().nullable().optional(),
	date: z.string().nullable().optional(),
	body_text: z.string().nullable().optional(),
	body_html: z.string().nullable().optional()
});

function formatAddress({ name, email }: z.infer<typeof gmailAddressSchema>): string {
	return name ? `${name} <${email}>` : email;
}

export async function getEmail(id: string): Promise<EmailMessage> {
	const message = await gwsJson(
		['gmail', '+read', '--id', id, '--headers', '--format', 'json'],
		gmailReadSchema
	);
	return {
		id,
		subject: message.subject ?? '',
		from: formatAddress(message.from),
		to: message.to.map(formatAddress).join(', '),
		date: message.date ?? '',
		bodyText: message.body_text ?? '',
		bodyHtml: message.body_html ?? '',
		attachments: []
	};
}

export const emailClient: EmailClient = {
	async searchSummaries({ query = 'in:inbox', max = 20 } = {}) {
		const data = await gwsJson(
			[
				'gmail',
				'+triage',
				'--query',
				query,
				'--max',
				String(max),
				'--format',
				'json'
			],
			gmailTriageSchema
		);
		return (data.messages ?? []).map((message) => ({
			id: message.id,
			from: message.from,
			subject: message.subject ?? '',
			date: message.date ?? ''
		}));
	},
	async listEmails({ query = 'in:inbox', max = 50 } = {}) {
		const list = await gwsJson(
			[
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
			],
			gmailMessageListSchema
		);
		if (!list.messages?.length) return [];
		return Promise.all(list.messages.map((message) => getEmail(message.id)));
	},
	getEmail,
	async markAsRead(id) {
		await gwsJson(['gmail', 'users', 'messages', 'markAsRead', '--id', id], z.unknown());
	},
	async markAsUnread(id) {
		await gwsJson(['gmail', 'users', 'messages', 'markAsUnread', '--id', id], z.unknown());
	}
};
