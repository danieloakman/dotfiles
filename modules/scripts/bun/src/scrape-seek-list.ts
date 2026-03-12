import { and, eq, desc } from 'drizzle-orm';
import { db, jobs } from './db';
import { $ } from 'bun';
import { Dayjs, raise, safeParseInt, question } from '@danoaky/js-utils';
import { readJob, updateJob, deleteJob } from './db/jobs';
import { open } from './utils/misc';

const readAllNotAppliedJobs = () =>
	db
		.select({
			id: jobs.id,
			url: jobs.url,
			title: jobs.title,
			company: jobs.company,
			isQuickApply: jobs.isQuickApply,
			relevance: jobs.relevance,
			postedAt: jobs.postedAt
			// location: jobs.location
		})
		.from(jobs)
		.where(and(eq(jobs.applied, false)))
		.orderBy(desc(jobs.isQuickApply), desc(jobs.relevance), desc(jobs.postedAt))
		.execute();

const idRe = /\| (\d+)$/;

const ACTIONS = [
	'1: Open URL',
	'2: Update: Applied',
	'3: Update: Low relevance',
	'4: Delete',
	'5: Back'
] as const;
type Action = (typeof ACTIONS)[number];
const ACTIONS_JOINED = ACTIONS.join('\n');

if (import.meta.main) {
	while (true) {
		const results = await readAllNotAppliedJobs();
		const selectJobs = results
			.map(({ title, relevance, postedAt, id, isQuickApply }) =>
				[
					`R${relevance}${isQuickApply ? ' Q' : ''}`,
					postedAt && Dayjs(postedAt).fromNow(),
					title,
					id
				]
					.filter(Boolean)
					.join(' | ')
			)
			.join('\n');
		const rawSelected =
			await $`echo "${selectJobs}" | fzf --header "Select a job" || echo ""`.text();
		if (rawSelected.trim() === '') break;
		const selected = rawSelected.trim().match(idRe);
		const id = safeParseInt(selected?.[1] ?? '') ?? raise('Invalid job ID');

		jobLoop: while (true) {
			const job = (await readJob(id)) ?? raise('Job not found');
			const choice =
				(await $`echo ${ACTIONS_JOINED} | fzf --header "${[job.title, job.company, job.location].filter(Boolean).join(' | ')}" || echo "${ACTIONS.at(-1)}"`.text()) as Action;
			switch (choice.trim()) {
				case '1: Open URL':
					await open(job.url);
					break;
				case '2: Update: Applied':
					await updateJob(id, { applied: true });
					console.log(`Applied to job ${id}: ${job.title}`);
					break jobLoop;
				case '3: Update: Low relevance':
					await updateJob(id, { relevance: 1 });
					console.log(`Low relevance to job ${id}: ${job.title}`);
					break jobLoop;
				case '4: Delete':
					const confirm = await question('Are you sure you want to delete this job? (y/n) ', 'n');
					if (confirm.trim().toLowerCase() === 'y') await deleteJob(id);
					console.log(`Deleted job ${id}: ${job.title}`);
					break jobLoop;
				default:
					break jobLoop;
			}
		}
	}
}
