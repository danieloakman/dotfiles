import { Database } from 'bun:sqlite';
import { drizzle } from 'drizzle-orm/bun-sqlite';
import { projectdir, SQLITE_DB_FILE } from '../utils/env';
import { execSync } from '@danoaky/js-utils';
import { $ } from 'bun';

const sqlite = new Database(SQLITE_DB_FILE);
export const db = drizzle(sqlite);

export async function initDb() {
	await $`
    cd ${projectdir}
    bun db:migrate
  `;
}
