import { $ } from 'bun';
import { platform } from 'os';

const OPEN_CMD = platform() === 'darwin' ? 'open' : platform() === 'linux' ? 'xdg-open' : 'start';

export const open = async (arg: string) => $`${OPEN_CMD} ${arg}`;
