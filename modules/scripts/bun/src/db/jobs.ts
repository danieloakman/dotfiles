import { db } from './db';
import { jobs, type Job } from './schema';
import { eq } from 'drizzle-orm';
export const jobExists = (id: number) =>
	db
		.select()
		.from(jobs)
		.where(eq(jobs.id, id))
		.limit(1)
		.then((result) => result.length > 0);

export const createJob = (job: Job) => db.insert(jobs).values(job).onConflictDoNothing();

export const readJob = (id: number) =>
	db
		.select()
		.from(jobs)
		.where(eq(jobs.id, id))
		.limit(1)
		.then((result) => result[0]);

export const updateJob = (id: number, patch: Partial<Job>) =>
	db.update(jobs).set(patch).where(eq(jobs.id, id)).execute();

export const deleteJob = (id: number) => db.delete(jobs).where(eq(jobs.id, id)).execute();
