import { createPoll } from 'ags/time';
import Icon from '../components/Icon';
const INT_REGEX = /^\d+$/;

export const uptime = createPoll('', 60000, 'uptime').as((stdout) => {
  const [, up, time] = stdout.split('  ');
  const days = parseInt(up?.match(INT_REGEX)?.[0] ?? '0');
  const [hours = 0, minutes = 0] = time?.replace(',', '')?.split(':').map(Number) ?? [0, 0];
  return [hours + 24 * days, minutes] as const;
});

export default function Uptime() {
  return (
    <box spacing={4}>
      <Icon name="hourglass" />
      <label label={uptime(([hours, minutes]) => `${hours}h, ${minutes}m`)} />
    </box>
  );
}
