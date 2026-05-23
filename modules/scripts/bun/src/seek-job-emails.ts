import meow from 'meow';
import { emailClient } from './utils/email';
import { Dayjs } from '@danoaky/js-utils';

if (import.meta.main) {
	const {
		flags: { days }
	} = meow(``, {
		importMeta: import.meta,
		flags: {
			days: { type: 'number', default: 21, aliases: ['d'] }
		}
	});

	const emails = await emailClient.listEmails({
		query: [
			'from:jobmail@s.seek.com.au',
			`after:${Dayjs().subtract(days, 'day').format('YYYY/MM/DD')}`
		].join(' '),
		max: 10
	});
	Bun.write('emails.json', JSON.stringify(emails, null, 2));
}
