import Icon from '@/components/Icon';
import { noop } from '@/js-utils';
import { createExternalState } from '@/utils/ags';
import { notify } from '@/utils/notifications';
import { classes } from '@/utils/styles';
import { Theme } from '@/utils/theme';
import { execAsync } from 'ags/process';

const [hypridleEnabled, setHypridleEnabled] = createExternalState<boolean>(false, (set) => {
  execAsync('hypridle-status')
    .then((stdout) => stdout.trim() === 'enabled')
    .then(set)
    .catch((err) => console.error('Failed to get hypridle status', err));
  return noop;
});

const toggleHypridle = () =>
  execAsync('hypridle-toggle')
    .then(async (stdout) => {
      const enabled = stdout.trim() === 'enabled';
      setHypridleEnabled(enabled);
      await notify({
        summary: 'Hypridle',
        body: enabled ? 'Enabled' : 'Disabled',
        icon: 'emblem-system-symbolic',
        transient: true,
      });
      return enabled;
    })
    .catch((err) => console.error('Failed to toggle hypridle', err));

/** hypridle inhibitor widget */
export default function Coffee() {
  return (
    <box name="Coffee">
      <button
        cssClasses={hypridleEnabled((v) => classes('rounded', !v && 'bg-fg-color'))}
        onClicked={toggleHypridle}
        tooltipText="Disable idle timeouts and keep the screen and system awake"
      >
        <Icon name="coffee" color={hypridleEnabled((v) => (v ? Theme.fgColor : Theme.bgColor))} />
      </button>
    </box>
  );
}
