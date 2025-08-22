import { With } from 'ags';
import { createPoll } from 'ags/time';

export const uptime = createPoll(
  '',
  60000,
  'uptime',
)((s) => {
  const match = s.match(/up\s+(\d+:\d+)/)?.[1] ?? '00:00';
  const [hours, minutes] = match.split(':').map(Number);
  return [hours, minutes] as const;
});

export default function Uptime() {
  return (
    <box>
      <With value={uptime}>{([hours, minutes]) => <label label={`Uptime: ${hours}h, ${minutes}m`} />}</With>
    </box>
  );
}
