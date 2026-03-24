import { and, eq, desc, lt, gt } from 'drizzle-orm';
import { db, jobs } from './db';
import { $ } from 'bun';
import { Dayjs, raise, safeParseInt, question, once, txt, addTimeout, truncate } from '@danoaky/js-utils';
import { readJob, updateJob, deleteJob } from './db/jobs';
import { open } from './utils/misc';
import { getBiggestParameterModelId, prompt } from './utils/ai';
import { downloadResumeText } from './utils/my-resume';
import clipboard from 'clipboardy';

const CUTOFF_TIME = Dayjs().subtract(28, 'day').toDate();
const readAllNotAppliedJobs = async () =>
	(await db())
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
		.where(and(eq(jobs.applied, false), gt(jobs.postedAt, CUTOFF_TIME)))
		.orderBy(desc(jobs.relevance), desc(jobs.isQuickApply), desc(jobs.postedAt))
		.limit(100)
		.execute();

const idRe = /\| *(\d+)$/;

const resumeText = once(() => downloadResumeText());

enum ActionStatus {
	Continue = 'continue',
	BreakJobLoop = 'break-job-loop',
	Break = 'break'
}

if (import.meta.main) {
	while (true) {
		const results = await readAllNotAppliedJobs();
		if (!results.length) {
			console.log('No jobs to show');
			break;
		}
		const selectJobs = results
			.map(({ title, relevance, postedAt, id, isQuickApply }) =>
				[
					`R${relevance?.toString().padEnd(3, ' ')}${isQuickApply ? ' Q' : '  '}`,
					postedAt && Dayjs(postedAt).fromNow().padEnd(12, ' '),
					truncate(title.padEnd(60, ' '), { length: 60 }),
					id
				]
					.filter(Boolean)
					.join('|')
			)
			.join('\n');
		const rawSelected =
			await $`echo "${selectJobs}" | fzf --header "Select a job" || echo ""`.text();
		if (rawSelected.trim() === '') break;
		const selected = rawSelected.trim().match(idRe);
		const id = safeParseInt(selected?.[1] ?? '') ?? raise('Invalid job ID');

		jobLoop: while (true) {
			const job = (await readJob(id)) ?? raise('Job not found');
			const actions = {
				'1: Open URL': async () => {
					await open(job.url);
					return ActionStatus.Continue;
				},
				'2: Update: Applied': async () => {
					await updateJob(id, { applied: true });
					console.log(`Applied to job ${id}: ${job.title}`);
					return ActionStatus.BreakJobLoop;
				},
				'3: Update: Relevance': async () => {
					const relevance = await question(
						`Relevance currently at ${job.relevance}/100. Update to? `
					);
					const relevanceInt = safeParseInt(relevance) ?? raise('Invalid relevance input');
					await updateJob(id, { relevance: relevanceInt });
					console.log(`Update relevance to job ${id}: ${job.title}`);
					return ActionStatus.Break;
				},
				'4: Ask AI': async () => {
					const q = (await question(`Ask AI about job ${job.title}: \n`, '')).trim();
					if (!q) return ActionStatus.Continue;
					console.log('Asking AI...');
					const r = await prompt(await getBiggestParameterModelId(), [
						{
							role: 'system',
							content: txt`
								You are a helpful assistant that can answer questions about the following job listing:
								${JSON.stringify(job)}

								The user's resume is as follows:
								${await resumeText()}
							`
						},
						{
							role: 'user',
							content: q
						}
					]);
					const response = r.choices
						.map((c) => c.message.content)
						.join('\n')
						.trim();
					console.log(response + '\n\n');
					await addTimeout(() => clipboard.write(response), 1000)(); // clipboard write sometimes hangs but still copies to clipboard
					await question('Press Enter to continue... (Copied to clipboard)');
					return ActionStatus.Continue;
				},
				'5: Write Cover Letter': async () => {
					const extra = await question(
						'Extra information to tell the AI about writing the cover letter (optional):\n',
						''
					);
					console.log('Writing cover letter...');
					const r = await prompt(await getBiggestParameterModelId(), [
						{
							role: 'system',
							content: txt`
								You are a helpful assistant that can write cover letters for job listings. These cover letters should be in reference to the user's resume and be in first person.

							  ---
								# USER RESUME
								${await resumeText()}
								---
							`
						},
						{
							role: 'user',
							content: txt`
								Write a cover letter for the following job listing.

								---
								# JOB LISTING
								${JSON.stringify(job)}
								---

								${extra}
							`
						}
					]);
					const response = r.choices
						.map((c) => c.message.content)
						.join('\n')
						.trim();
					console.log(response + '\n\n');
					await addTimeout(() => clipboard.write(response), 1000)(); // clipboard write sometimes hangs but still copies to clipboard
					await question('Press Enter to continue... (Copied to clipboard)');
					return ActionStatus.Continue;
				},
				'6: Delete': async () => {
					const confirm = await question('Are you sure you want to delete this job? (y/n) ', 'n');
					if (confirm.trim().toLowerCase() === 'y') await deleteJob(id);
					console.log(`Deleted job ${id}: ${job.title}`);
					return ActionStatus.BreakJobLoop;
				},
				'7: Back': async () => {
					return ActionStatus.BreakJobLoop;
				}
			};
			const actionKeys = Object.keys(actions);
			const choice =
				await $`echo ${actionKeys.join('\n')} | fzf --header "${[`R${job.relevance}${job.isQuickApply ? ' Q' : ''}`, job.title, job.company, job.location].filter(Boolean).join(' | ')}" || echo "${actionKeys.at(-1)}"`.text();
			const status =
				(await actions[choice.trim() as keyof typeof actions]()) ?? ActionStatus.Continue;
			if (status === ActionStatus.BreakJobLoop) break jobLoop;
			if (status === ActionStatus.Break) break;
		}
	}
}
