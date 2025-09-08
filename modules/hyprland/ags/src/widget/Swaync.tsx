import { Icon } from '@/components/Icon';
import { classes } from '../utils/styles';
import { execAsync } from 'ags/process';
import { swayncStatus } from '@/utils/notifications';

export default function Swaync() {
  return (
    <button
      name="SwayNC"
      cssClasses={classes('rounded')}
      onClicked={() => execAsync('swaync-client -t')}
    >
      <Icon
        name={swayncStatus(({ dnd, count }) =>
          dnd ? 'bell-off' : count > 0 ? 'bell-dot' : 'bell',
        )}
      />
    </button>
  );
}
