import { execAsync } from 'ags/process';
import Icon from '../components/Icon';
import { classes } from '../utils/styles';
import { Vr } from '../components/Separators';
import { devices, hasTouchDevice, monitors } from '../utils/hyprland';
import { noop, raise } from '../utils/fn';
import { createExternal } from 'ags';

export type RotateDirection = 'cw' | 'ccw';
export type RotateTransform = 0 | 1 | 2 | 3;

/** 0: normal, 1: 90°, 2: 180°, 3: 270° */
let currentTransform: RotateTransform = 0;
const TRANSFORM_MAP: Record<`${RotateDirection}-${RotateTransform}`, RotateTransform> = {
  'cw-0': 1,
  'cw-1': 2,
  'cw-2': 3,
  'cw-3': 0,
  'ccw-0': 3,
  'ccw-1': 0,
  'ccw-2': 1,
  'ccw-3': 2,
};

/** Rotates both the display and touch screen input devices. */
export async function rotateOrientation(direction: RotateDirection) {
  const nextTransform = TRANSFORM_MAP[`${direction}-${currentTransform}`];

  const allMonitors = monitors.get();
  if (allMonitors.length > 1) throw new Error('Multiple monitors not supported for rotation');
  const monitor = allMonitors[0] ?? raise('No monitor found');

  await execAsync(
    `hyprctl keyword monitor ${monitor.name},preferred,auto,1,transform,${nextTransform}`,
  );

  const _devices = await devices();
  if (_devices?.touch?.length)
    await execAsync(`hyprctl keyword input:touchdevice:transform ${nextTransform}`).catch((err) =>
      console.error('Failed to rotate touch device', err),
    );
  if (_devices?.tablets?.length)
    await execAsync(`hyprctl keyword input:tablet:transform ${nextTransform}`).catch((err) =>
      console.error('Failed to rotate tablet', err),
    );

  currentTransform = nextTransform;
}

export default function Orientation() {
  const visible = createExternal(false, (set) => {
    hasTouchDevice().then(set);
    return noop;
  });
  return (
    <box
      name="orientation"
      visible={visible}
      spacing={4}
      cssClasses={classes('selected', 'rounded-full')}
    >
      <button
        onClicked={() => rotateOrientation('cw')}
        cssClasses={classes('rounded-full', 'btn-ghost')}
      >
        <Icon name="rotate-ccw" />
      </button>

      <Vr cssClasses={classes('color-fg-color', 'my-xs')} />

      <button
        onClicked={() => rotateOrientation('ccw')}
        cssClasses={classes('rounded-full', 'btn-ghost')}
      >
        <Icon name="rotate-cw" />
      </button>
    </box>
  );
}
