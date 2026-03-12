import { defineConfig } from 'drizzle-kit';
import { SQLITE_DB_FILE } from './src/utils/env';

export default defineConfig({
  schema: './src/db/schema.ts',
  out: './drizzle',
  dialect: 'sqlite',
  dbCredentials: {
    url: `file:${SQLITE_DB_FILE}`,
  },
});
