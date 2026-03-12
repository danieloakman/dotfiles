import { sqliteTable, text, integer } from 'drizzle-orm/sqlite-core';
import { createInsertSchema, createSelectSchema } from 'drizzle-zod';

const boolean = (name: string) => integer(`${name}_id`, { mode: 'boolean' });

export const jobs = sqliteTable('jobs', {
	id: integer('id').primaryKey().notNull(),
	url: text('url').notNull(),
	title: text('title').notNull(),
	description: text('description').notNull(),
	applied: boolean('applied').default(false),
	company: text('company'),
	location: text('location'),
	isQuickApply: boolean('is_quick_apply'),
	workType: text('work_type'),
	salary: text('salary'),
	postedAt: integer('posted_at', { mode: 'timestamp_ms' }),
	/** 0-100 relevance score to the user's resume */
	relevance: integer('relevance')
});

export type Job = typeof jobs.$inferSelect;

export const selectJobSchema = createSelectSchema(jobs);
export const insertJobSchema = createInsertSchema(jobs);
