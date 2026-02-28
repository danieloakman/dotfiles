import { platform } from 'os';
import XYDoTool from './XYDoTool';
import { exec, Result, sh } from '@danoaky/js-utils';

export async function getMousePosition(): Promise<[x: number, y: number]> {
  if (platform() === 'darwin') {
    const stdout = Result.unwrap(await exec(`cliclick p`));
    return stdout.split(',').map(Number) as [x: number, y: number];
  }
  throw new Error('Not implemented');
}

/** Move the mouse relative to the current position. */
export async function moveMouse(x: number, y: number) {
  if (platform() === 'darwin') {
    const [ox = 0, oy = 0] = await getMousePosition();
    await sh(`cliclick m:${x + ox},${y + oy}`);
  } else {
    const xydotool = await XYDoTool.instance();
    await xydotool.moveMouse(x, y);
  }
}
