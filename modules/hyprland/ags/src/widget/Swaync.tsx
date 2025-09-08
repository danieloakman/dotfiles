import { Icon } from '@/components/Icon';
import { classes } from '../utils/styles';
import { execAsync } from 'ags/process';
import { swayncStatus } from '@/utils/notifications';
import { StyleClass } from '@/types/style-classes';
import { hideWindow } from '@/utils/window';

export async function toggleSwayncPanel() {
  await execAsync('swaync-client -t').catch((err) =>
    console.error('Failed to toggle SwayNC panel', err),
  );
}

export interface SwayncProps {
  visible?: boolean;
  cssClasses?: StyleClass[];
}

export default function Swaync({ visible, cssClasses = [] }: SwayncProps) {
  return (
    <button
      visible={visible}
      name="SwayNC"
      cssClasses={classes('rounded', ...cssClasses)}
      onClicked={async () => {
        hideWindow('control-center');
        await toggleSwayncPanel();
      }}
    >
      <Icon
        name={swayncStatus(({ dnd, count }) =>
          dnd ? 'bell-off' : count > 0 ? 'bell-dot' : 'bell',
        )}
      />
    </button>
  );
}
