import Icon from '@/components/Icon';
import { createBooleanState } from '@/utils/ags';
import { randInt } from '@/utils/number';
import { classes } from '@/utils/styles';
import { Theme } from '@/utils/theme';
import { onCleanup, With } from 'ags';
import { execAsync } from 'ags/process';
import { interval } from 'ags/time';

const INTERVAL = 60000 * 2;

export default function MoveMouse() {
  const [enabled, { toggle: toggleEnabled }] = createBooleanState(false);

  return (
    <box name="MoveMouse">
      <button
        cssClasses={enabled((v) => classes('rounded', v && 'bg-fg-color'))}
        onClicked={toggleEnabled}
      >
        <Icon name="mouse-pointer" color={enabled((v) => (v ? Theme.bgColor : Theme.fgColor))} />
      </button>
      <With value={enabled}>
        {(enabled) => {
          if (!enabled) return null;
          return <Impl />;
        }}
      </With>
    </box>
  );
}

function Impl() {
  const timer = interval(INTERVAL, () =>
    execAsync(`ydotool mousemove -x ${randInt(-50, 50)} -y ${randInt(-50, 50)}`).catch((err) =>
      console.log(err),
    ),
  );
  onCleanup(() => timer.cancel());
  return <box name="timer-active"></box>;
}
