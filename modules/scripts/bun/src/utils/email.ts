import { z } from 'zod';
import { gwsJson } from './gws';

export interface EmailMessage {
	id: string;
	subject: string;
	from: string;
	to: string;
	date: string;
	body: string;
	attachments: unknown[];
}

export interface EmailClient {
	listEmails(options?: {
		/** Gmail search query, e.g. `from:boss is:unread`. Defaults to `in:inbox`. */
		query?: string;
		max?: number;
	}): Promise<EmailMessage[]>;
	markAsRead(id: string): Promise<void>;
	markAsUnread(id: string): Promise<void>;
}

const gmailMessageListSchema = z.object({
	messages: z.array(z.object({ id: z.string(), threadId: z.string() })).optional()
});

const gmailMessageSchema = z.object({
	id: z.string(),
	snippet: z.string().optional(),
	payload: z
		.object({
			headers: z.array(z.object({ name: z.string(), value: z.string() })).optional()
		})
		.optional()
});

async function fetchMessage(id: string): Promise<EmailMessage> {
	const message = await gwsJson(
		[
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
		],
		gmailMessageSchema
	);
	const headers =
		message.payload?.headers?.reduce(
			(acc, header) => {
				acc[header.name] = header.value;
				return acc;
			},
			{} as Record<string, string>
		) ?? {};
	return {
		id: message.id,
		subject: headers['Subject'] ?? '',
		from: headers['From'] ?? '',
		to: headers['To'] ?? '',
		date: headers['Date'] ?? '',
		body: message.snippet ?? '',
		attachments: []
	};
}

export const emailClient: EmailClient = {
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
		return Promise.all(list.messages.map((message) => fetchMessage(message.id)));
	},
	async markAsRead(id) {
		await gwsJson(
			['gmail', 'users', 'messages', 'markAsRead', '--id', id],
			z.unknown()
		);
	},
	async markAsUnread(id) {
		await gwsJson(
			['gmail', 'users', 'messages', 'markAsUnread', '--id', id],
			z.unknown()
		);
	}
};
