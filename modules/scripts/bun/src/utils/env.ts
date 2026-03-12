import { once } from '@danoaky/js-utils';
import { existsSync, mkdirSync } from 'fs';
import { join } from 'path';
import { homedir, tmpdir as osTmpdir } from 'os';

export const cachedir = once(() => {
	const dir = IS_DEV ? join(__dirname, '../../.cache') : join(homedir(), '.cache', 'bun-scripts');
	if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
	return dir;
});

export const tmpdir = once(() => {
	const dir = join(osTmpdir(), 'bun-scripts');
	if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
	return dir;
});

export const IS_ON_WAYLAND = process.env.XDG_SESSION_TYPE === 'wayland';

export const IS_DEV = process.env.NODE_ENV !== 'production';

export const SQLITE_DB_FILE = process.env.DB_FILE || join(cachedir(), 'sqlite.db');

export const AUTH_FILE = process.env.PLAYWRIGHT_AUTH_FILE || join(cachedir(), 'auth.json');
