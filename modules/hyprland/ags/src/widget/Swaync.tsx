import { Icon } from '@/components/Icon';
import { classes } from '../utils/styles';
import { execAsync } from 'ags/process';
import { swayncStatus } from '@/utils/notifications';
import { StyleClass } from '@/types/style-classes';

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
