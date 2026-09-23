import { createPoll } from 'ags/time';
import Icon from '../components/Icon';

// Parse /proc/uptime (seconds since boot) — avoids fragile `uptime` CLI formatting
// that differs for "1 day" vs "N days" and minutes-only uptimes (#27).
export const uptime = createPoll('', 60000, 'cat /proc/uptime').as((stdout) => {
  const totalSeconds = Math.floor(Number.parseFloat(stdout.split(/\s+/)[0] ?? '0'));
  if (!Number.isFinite(totalSeconds) || totalSeconds < 0) return [0, 0] as const;
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  return [hours, minutes] as const;
});

export default function Uptime() {
  return (
    <box spacing={4}>
      <Icon name="hourglass" />
      <label label={uptime(([hours, minutes]) => `${hours}h, ${minutes}m`)} />
    </box>
  );
}
