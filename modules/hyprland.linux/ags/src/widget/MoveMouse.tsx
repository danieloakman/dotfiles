import Icon from '@/components/Icon';
import { createBooleanState } from '@/utils/ags';
import { classes } from '@/utils/styles';
import { Theme } from '@/utils/theme';
import { createComputed } from 'ags';
import { createIsIdle, moveCursorRelative } from '@/utils/hyprland';
import { useSubscribe } from '../utils/ags';
import { randInteger } from '@/js-utils';

const INTERVAL = 60000 * 2;

// TODO: this is no longer working after adding the idle detection. Perhaps just make it move the mouse regardless of idle state.
export default function MoveMouse() {
  const [enabled, { toggle: toggleEnabled }] = createBooleanState(false);
  const isIdle = createIsIdle(INTERVAL);
  useSubscribe(
    createComputed([enabled, isIdle], (enabled, isIdle) => enabled && isIdle),
    (enabled) => {
      if (!enabled) return;
      console.log('moving mouse');
      moveCursorRelative(randInteger(-50, 50), randInteger(-50, 50));
    },
  );

  return (
    <box name="MoveMouse">
      <button
        cssClasses={enabled((v) => classes('rounded', v && 'bg-fg-color'))}
        onClicked={toggleEnabled}
      >
        <Icon name="mouse-pointer" color={enabled((v) => (v ? Theme.bgColor : Theme.fgColor))} />
      </button>
    </box>
  );
}
