import meow from 'meow';
import { emailClient } from './utils/email';
import { Dayjs, matches, question, safeParseInt } from '@danoaky/js-utils';
import { iter } from 'iteragain';
import { startsWith } from 'zod';
import { open } from './utils/misc';
import { createJob, jobExists, readJob, updateJob } from './db/jobs';

const seekJobIdRe = /https:\/\/au\.seek\.com\/job\/(\d+)/g;

const textAround = (str: string, index: number) => {
	const start = str.slice(0, index).lastIndexOf('\r\n\r\n');
	const end = str.slice(index).indexOf('\r\n\r\n');
	return str.slice(start, end + index);
};

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
		.flatMap(({ bodyText, subject }) => {
			console.log('Subject:', subject);
			return iter(matches(seekJobIdRe, bodyText)).filterMap((m) => {
				const [url, jobIdStr] = m;
				const jobId = safeParseInt(jobIdStr ?? '') ?? null;
				if (!jobId || !url) return null;
				return { url, jobId, text: textAround(bodyText, m.index) };
			});
		})
		.unique(({ jobId }) => jobId);

	for (const { url, jobId, text } of jobs) {
		const job = await readJob(jobId);
		if (!job)
			await createJob({
				applied: false,
				company: '',
				description: '',
				url,
				id: jobId,
				title: '',
				location: '',
				isQuickApply: false,
				workType: '',
				salary: '',
				postedAt: new Date(),
				relevance: 0
			});
		else if (job.applied) continue;

		console.log(text);

		const answer = await question('Open in browser? (y/n)');
		if (answer.toLowerCase() === 'y') {
			await open(url);
			await updateJob(jobId, { applied: true });
		}
	}
}
