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

const gmailAddressSchema = z.object({
	name: z.string().nullable().optional(),
	email: z.string()
});

const gmailReadSchema = z.object({
	from: gmailAddressSchema,
	to: z.array(gmailAddressSchema),
	subject: z.string().optional(),
	date: z.string().optional(),
	body_text: z.string().optional(),
	body_html: z.string().optional()
});

function formatAddress({ name, email }: z.infer<typeof gmailAddressSchema>): string {
	return name ? `${name} <${email}>` : email;
}

async function fetchMessage(id: string): Promise<EmailMessage> {
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
		body: message.body_text ?? message.body_html ?? '',
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
