import { Database } from 'bun:sqlite';
import { drizzle } from 'drizzle-orm/bun-sqlite';
import { PROJECT_DIR, SQLITE_DB_FILE } from '../utils/env';
import { $ } from 'bun';
import { once, safeParseInt } from '@danoaky/js-utils';

const sqlite = new Database(SQLITE_DB_FILE);
export const db = once(async () => {
	await initDb();
	return drizzle(sqlite);
});

const TABLES_RE = /(\d+) table fetched/;

export async function introspectDb() {
	const result = await $`
    cd ${PROJECT_DIR}
    bun db:introspect
  `.text();
	const tables = safeParseInt(result.match(TABLES_RE)?.[1] ?? '0') ?? 0;
	return { tables };
}

export async function initDb() {
	// const { tables } = await introspectDb();
	await $`
    cd ${PROJECT_DIR}
    bun db:push
  `.quiet();
}
