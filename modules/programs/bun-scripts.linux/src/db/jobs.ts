import { db } from './db';
import { jobs, type Job } from './schema';
import { eq } from 'drizzle-orm';
export const jobExists = async (id: number) =>
	(await db())
		.select()
		.from(jobs)
		.where(eq(jobs.id, id))
		.limit(1)
		.then((result) => result.length > 0);

export const createJob = async (job: Job) =>
	(await db()).insert(jobs).values(job).onConflictDoNothing();

export const readJob = async (id: number) =>
	(await db())
		.select()
		.from(jobs)
		.where(eq(jobs.id, id))
		.limit(1)
		.then((result) => result[0]);

export const updateJob = async (id: number, patch: Partial<Job>) =>
	(await db()).update(jobs).set(patch).where(eq(jobs.id, id)).execute();

export const deleteJob = async (id: number) =>
	(await db()).delete(jobs).where(eq(jobs.id, id)).execute();
