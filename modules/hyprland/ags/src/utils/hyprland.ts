import { createBinding } from 'ags';
import { once } from './fn';
import { safeJSONParse } from './object';
import { execAsync } from 'ags/process';
import Hyprland from 'gi://AstalHyprland';

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
  execAsync('hyprctl devices -j').then(safeJSONParse<HyprlandDevices>),
);

/** Whether the system has a device like a touch screen. */
export const hasTouchDevice = () =>
  devices().then((devices) => ((devices?.touch?.length || devices?.tablets?.length) ?? 0) > 0);
