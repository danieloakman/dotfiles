import { describe, expect, test as it } from 'bun:test';
import {
	collectAttachments,
	decodeGmailBase64,
	resolveDownloadPath
} from './email';

describe('collectAttachments', () => {
	it('walks nested parts and marks inline', () => {
		const attachments = collectAttachments({
			mimeType: 'multipart/mixed',
			parts: [
				{
					mimeType: 'text/plain',
					body: { data: 'aGVsbG8=', size: 5 }
				},
				{
					filename: 'image001.png',
					mimeType: 'image/png',
					headers: [
						{
							name: 'Content-Disposition',
							value: 'inline; filename="image001.png"'
						}
					],
					body: { attachmentId: 'att-inline', size: 12 }
				},
				{
					filename: 'quote.pdf',
					mimeType: 'application/pdf',
					headers: [
						{
							name: 'Content-Disposition',
							value: 'attachment; filename="quote.pdf"'
						}
					],
					body: { attachmentId: 'att-pdf', size: 99 }
				}
			]
		});

		expect(attachments).toEqual([
			{
				id: 'att-inline',
				filename: 'image001.png',
				mimeType: 'image/png',
				size: 12,
				inline: true
			},
			{
				id: 'att-pdf',
				filename: 'quote.pdf',
				mimeType: 'application/pdf',
				size: 99,
				inline: false
			}
		]);
	});

	it('sanitizes path separators in filenames', () => {
		const [att] = collectAttachments({
			filename: 'a/b\\c.pdf',
			mimeType: 'application/pdf',
			body: { attachmentId: 'x', size: 1 }
		});
		expect(att?.filename).toBe('a_b_c.pdf');
	});
});

describe('decodeGmailBase64', () => {
	it('decodes URL-safe base64 without padding', () => {
		const bytes = decodeGmailBase64('SGVsbG8td29ybGQ'); // "Hello-world"
		expect(Buffer.from(bytes).toString('utf8')).toBe('Hello-world');
	});
});

describe('resolveDownloadPath', () => {
	it('joins filename when path is a directory', () => {
		expect(resolveDownloadPath('/tmp/out/', 'a.pdf')).toBe('/tmp/out/a.pdf');
	});

	it('uses path as file when not a directory', () => {
		expect(resolveDownloadPath('/tmp/out/file.pdf', 'a.pdf')).toBe('/tmp/out/file.pdf');
	});
});
