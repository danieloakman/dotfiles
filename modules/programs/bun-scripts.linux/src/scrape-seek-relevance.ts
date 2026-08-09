import { jobs } from './db';
import { attempt, Dayjs, pick } from '@danoaky/js-utils';
import { db } from './db';
import { desc, gt, eq, and } from 'drizzle-orm';
import { downloadResumeText } from './utils/my-resume';
import { z } from 'zod';
import { getBestCodingModelId, structuredPrompt } from './utils/ai';
import { iter } from 'iteragain';

const CUTOFF_TIME = Dayjs().subtract(28, 'day').toDate();
const readAllNotAppliedJobs = async (limit = 10, offset = 0) =>
	(await db())
		.select({
			title: jobs.title,
			company: jobs.company,
			relevance: jobs.relevance,
			location: jobs.location,
			workType: jobs.workType,
			description: jobs.description
		})
		.from(jobs)
		.where(and(eq(jobs.applied, false), gt(jobs.postedAt, CUTOFF_TIME)))
		.orderBy(desc(jobs.relevance), desc(jobs.isQuickApply), desc(jobs.postedAt))
		.limit(limit)
		.offset(offset)
		.execute();

if (import.meta.main) {
	const jobs = await readAllNotAppliedJobs();
	const resumeText = await downloadResumeText();

	const relevancePrompt = `
Here is my current resume:
---
${resumeText}
---

Now find the relevance score (integer value between 0 and 100) for each of the following jobs:
---
${JSON.stringify(jobs.map((job) => pick(job, ['title', 'company', 'description', 'location', 'workType'])))}
---
	`;
	const { status, data, error } = await attempt(
		structuredPrompt(
			await getBestCodingModelId(),
			relevancePrompt,
			z.object({
				relevance: z
					.array(z.number().min(0).max(100))
					.length(jobs.length)
					.describe('The relevance score for each job')
			})
		)
	);
  if (status !== 'success') throw new Error(`Failed to calculate relevance, error: ${error}`);
  // TODO: Update jobs with relevance
	console.log(
		iter(data.relevance)
			.zip(jobs)
			.map(([relevance, job]) => `${job.relevance} -> ${relevance}`)
			.toArray()
	);
}
