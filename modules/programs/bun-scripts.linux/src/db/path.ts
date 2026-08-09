import { join } from 'path';
import { cachedir } from '../utils/env';

/** DB path in a Node-safe module so drizzle-kit (runs on Node) can import it. */
export const SQLITE_DB_PATH = join(cachedir(), 'sqlite.db');
