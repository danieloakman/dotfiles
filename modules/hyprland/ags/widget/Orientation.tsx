import { execAsync } from 'ags/process';
import Icon from '../components/Icon';

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

/** NOTE: This doesn't rotate the touch screen input. Only rotates the display. */
export async function rotateOrientation(direction: RotateDirection) {
  const nextTransform = TRANSFORM_MAP[`${direction}-${currentTransform}`];
  await execAsync(`hyprctl keyword monitor eDP-1,preferred,auto,1,transform,${nextTransform}`);
  currentTransform = nextTransform;
}

export default function Orientation() {
  return (
    <box spacing={4}>
      <button onClicked={() => rotateOrientation('cw')}>
        <Icon name="rotate-cw" />
      </button>

      <button onClicked={() => rotateOrientation('ccw')}>
        <Icon name="rotate-ccw" />
      </button>
    </box>
  );
}
