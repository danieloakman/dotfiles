import Icon from '@/components/Icon';
import { createBooleanState } from '@/utils/ags';
import { randInt } from '@/utils/number';
import { classes } from '@/utils/styles';
import { Theme } from '@/utils/theme';
import { createComputed, onCleanup, With } from 'ags';
import { interval } from 'ags/time';
import { createIsIdle, moveCursorRelative } from '@/utils/hyprland';

const INTERVAL = 60000 * 2;

export default function MoveMouse() {
  const [enabled, { toggle: toggleEnabled }] = createBooleanState(false);
  const isIdle = createIsIdle(INTERVAL);

  return (
    <box name="MoveMouse">
      <button
        cssClasses={enabled((v) => classes('rounded', v && 'bg-fg-color'))}
        onClicked={toggleEnabled}
      >
        <Icon name="mouse-pointer" color={enabled((v) => (v ? Theme.bgColor : Theme.fgColor))} />
      </button>
      <With value={createComputed([enabled, isIdle], (enabled, isIdle) => enabled && isIdle)}>
        {(enabled: boolean) => {
          if (!enabled) return null;
          return <Impl />;
        }}
      </With>
    </box>
  );
}

function Impl() {
  const timer = interval(INTERVAL, () => moveCursorRelative(randInt(-50, 50), randInt(-50, 50)));
  onCleanup(() => timer.cancel());
  return <box name="timer-active"></box>;
}
