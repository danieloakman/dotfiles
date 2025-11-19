import Icon from '@/components/Icon';
import { createInterval, useSubscribe } from '@/utils/ags';
import { notify } from '@/utils/notifications';
import { classes } from '@/utils/styles';
import { Theme } from '@/utils/theme';
import { createState } from 'ags';
import { execAsync } from 'ags/process';

const isHypridleEnabled = () =>
  execAsync('hypridle-status')
    .then((stdout) => stdout.trim() === 'enabled')
    .catch((err) => {
      console.error('Failed to get hypridle status', err);
      return false;
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

const [hypridleEnabled, setHypridleEnabled] = createState<boolean>(false);

/** hypridle inhibitor widget */
export default function Coffee() {
  useSubscribe(createInterval(10000), async () => {
    const enabled = await isHypridleEnabled();
    if (enabled !== hypridleEnabled.get()) setHypridleEnabled(enabled);
  });

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
