import { Icon } from '@/components/Icon';
import { classes } from '../utils/styles';
import { execAsync } from 'ags/process';

export default function Swaync() {
  return (
    <button name="SwayNC" cssClasses={classes('rounded')} onClicked={() => execAsync('swaync-client -t')}>
      <Icon name="bell" />
    </button>
  );
}
