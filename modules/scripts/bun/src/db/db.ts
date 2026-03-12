import { Database } from 'bun:sqlite';
import { drizzle } from 'drizzle-orm/bun-sqlite';
import { SQLITE_DB_FILE } from '../utils/env';

const sqlite = new Database(SQLITE_DB_FILE);
export const db = drizzle(sqlite);
