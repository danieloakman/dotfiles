import meow from 'meow';
import { emailClient } from './utils/email';
import { Dayjs, matches } from '@danoaky/js-utils';
import { iter } from 'iteragain';

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
	const jobs = iter(emails)
		.flatMap(({ body }) => matches(/https:\/\/au\.seek\.com\/job\/(\d+)/g, body))
		.filterMap((m) => {
			const [url, jobId] = m;
			if (!jobId || !url) return null;
			return { url, jobId };
		})
		.unique(({ jobId }) => jobId)
		.toArray();
	await Bun.write('jobs.json', JSON.stringify(jobs, null, 2));
}
