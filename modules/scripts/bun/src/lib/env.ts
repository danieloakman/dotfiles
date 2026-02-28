import { once } from '@danoaky/js-utils';
import { existsSync, mkdirSync } from 'fs';
import { join } from 'path';
import { homedir } from 'os';

export const cacheDir = once(() => {
  const dir = join(homedir(), '.cache', 'bun-scripts');
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
  return dir;
});

export const isOnWayland = process.env.XDG_SESSION_TYPE === 'wayland';
