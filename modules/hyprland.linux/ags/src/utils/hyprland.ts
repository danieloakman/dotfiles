import { createBinding, createComputed } from 'ags';
import { once, pipe, safeJSONParse } from '@/js-utils';
import { execAsync } from 'ags/process';
import Hyprland from 'gi://AstalHyprland';
import { createInterval, distinctUntilChanged } from './ags';

export interface HyprlandDevice {
  [key: string]: unknown;
  name: string;
  address: string;
}

export interface HyprlandDevices {
  mice: HyprlandDevice[];
  keyboards: HyprlandDevice[];
  touch: HyprlandDevice[];
  tablets: HyprlandDevice[];
  switches: HyprlandDevice[];
}

const hyprland = Hyprland.get_default();

export const workspaces = createBinding(hyprland, 'workspaces').as((ws) =>
  ws.filter((w) => !w.name.includes('special')),
);

export const focusedWorkspace = createBinding(hyprland, 'focusedWorkspace');

export const focusedClient = createBinding(hyprland, 'focusedClient');

export const monitors = createBinding(hyprland, 'monitors');

export const devices = once(() =>
  execAsync('hyprctl devices -j')
    .then(safeJSONParse<HyprlandDevices>)
    .catch((err) => {
      console.error('Failed to get hyprland devices', err);
      return null;
    }),
);

export const hasTouchDevice = () =>
  devices().then((devices) => ((devices?.touch?.length || devices?.tablets?.length) ?? 0) > 0);

export const cursorPosition = pipe(
  createInterval(1000).as(() => ({
    x: hyprland.cursor_position.get_x(),
    y: hyprland.cursor_position.get_y(),
  })),
  distinctUntilChanged((prev, next) => prev.x === next.x && prev.y === next.y),
);

export const lastTimeCursorMoved = cursorPosition(() => Date.now());

/** Creates an accessor that is true if the cursor has been idle for the given `timeMs`. */
export const createIsIdle = (timeMs: number) =>
  pipe(
    createComputed(
      [lastTimeCursorMoved, createInterval(1000).as(() => Date.now())],
      (cursorTime, now) => cursorTime + timeMs < now,
    ),
    distinctUntilChanged(),
  );

export const moveCursorRelative = (x: number, y: number) => {
  try {
    const pos = hyprland.get_cursor_position();
    hyprland.move_cursor(pos.get_x() + x, pos.get_y() + y);
  } catch (err) {
    console.log('Error in moveCursor:', err);
  }
};
