import { join, resolve } from 'node:path';
import { z } from 'zod';
import { gwsJson } from './gws';

export interface EmailAttachment {
	/** Gmail `attachmentId` (pass to download). */
	id: string;
	filename: string;
	mimeType: string;
	size: number;
	/** True when Content-Disposition is inline (e.g. embedded images). */
	inline: boolean;
}

export interface EmailMessage {
	id: string;
	subject: string;
	from: string;
	to: string;
	date: string;
	bodyText: string;
	bodyHtml: string;
	/** Not populated by getEmail; use listAttachments. */
	attachments: EmailAttachment[];
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
	listAttachments(id: string): Promise<EmailAttachment[]>;
	downloadAttachment(options: {
		messageId: string;
		attachmentId: string;
		/** Destination file path (created/overwritten). */
		path: string;
	}): Promise<{ path: string; size: number }>;
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

type GmailPart = {
	filename?: string | null;
	mimeType?: string | null;
	headers?: { name: string; value: string }[];
	body?: { attachmentId?: string | null; size?: number | null; data?: string | null };
	parts?: GmailPart[];
};

const gmailPartSchema: z.ZodType<GmailPart> = z.lazy(() =>
	z.object({
		filename: z.string().nullable().optional(),
		mimeType: z.string().nullable().optional(),
		headers: z.array(z.object({ name: z.string(), value: z.string() })).optional(),
		body: z
			.object({
				attachmentId: z.string().nullable().optional(),
				size: z.number().nullable().optional(),
				data: z.string().nullable().optional()
			})
			.optional(),
		parts: z.array(gmailPartSchema).optional()
	})
);

const gmailFullMessageSchema = z.object({
	id: z.string(),
	payload: gmailPartSchema.optional()
});

const gmailAttachmentDataSchema = z.object({
	size: z.number().optional(),
	data: z.string()
});

function formatAddress({ name, email }: z.infer<typeof gmailAddressSchema>): string {
	return name ? `${name} <${email}>` : email;
}

function headerMap(part: GmailPart): Record<string, string> {
	return Object.fromEntries(
		(part.headers ?? []).map((h) => [h.name.toLowerCase(), h.value])
	);
}

/** Walk a Gmail message payload and collect parts that have an attachmentId. */
export function collectAttachments(payload: GmailPart | undefined): EmailAttachment[] {
	const out: EmailAttachment[] = [];
	const walk = (part: GmailPart | undefined) => {
		if (!part) return;
		const attachmentId = part.body?.attachmentId?.trim();
		if (attachmentId) {
			const headers = headerMap(part);
			const disposition = (headers['content-disposition'] ?? '').toLowerCase();
			const filename =
				part.filename?.trim() ||
				disposition.match(/filename\*?=(?:UTF-8''|")?([^";]+)/i)?.[1]?.trim() ||
				'attachment';
			out.push({
				id: attachmentId,
				filename: filename.replace(/[/\\]/g, '_'),
				mimeType: part.mimeType ?? 'application/octet-stream',
				size: part.body?.size ?? 0,
				inline: disposition.startsWith('inline')
			});
		}
		for (const child of part.parts ?? []) walk(child);
	};
	walk(payload);
	return out;
}

/** Gmail attachment bytes are base64url (RFC 4648 §5). */
export function decodeGmailBase64(data: string): Uint8Array {
	const padded = data.replace(/-/g, '+').replace(/_/g, '/');
	const pad = padded.length % 4 === 0 ? '' : '='.repeat(4 - (padded.length % 4));
	return Buffer.from(padded + pad, 'base64');
}

/** Resolve a download destination; directories are created by the caller via Bun.write parent. */
export function resolveDownloadPath(path: string, filename: string): string {
	const resolved = resolve(path);
	// If path looks like a directory (trailing slash / existing dir), join filename.
	if (path.endsWith('/') || path.endsWith('\\')) return join(resolved, filename);
	return resolved;
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

export async function listAttachments(id: string): Promise<EmailAttachment[]> {
	const message = await gwsJson(
		[
			'gmail',
			'users',
			'messages',
			'get',
			'--params',
			JSON.stringify({ userId: 'me', id, format: 'full' }),
			'--format',
			'json'
		],
		gmailFullMessageSchema
	);
	return collectAttachments(message.payload);
}

export async function downloadAttachment({
	messageId,
	attachmentId,
	path
}: {
	messageId: string;
	attachmentId: string;
	path: string;
}): Promise<{ path: string; size: number }> {
	const payload = await gwsJson(
		[
			'gmail',
			'users',
			'messages',
			'attachments',
			'get',
			'--params',
			JSON.stringify({
				userId: 'me',
				messageId,
				id: attachmentId
			}),
			'--format',
			'json'
		],
		gmailAttachmentDataSchema
	);

	const bytes = decodeGmailBase64(payload.data);
	const dest = resolve(path);
	await Bun.write(dest, bytes);
	return { path: dest, size: bytes.byteLength };
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
	listAttachments,
	downloadAttachment,
	async markAsRead(id) {
		await gwsJson(['gmail', 'users', 'messages', 'markAsRead', '--id', id], z.unknown());
	},
	async markAsUnread(id) {
		await gwsJson(['gmail', 'users', 'messages', 'markAsUnread', '--id', id], z.unknown());
	}
};
