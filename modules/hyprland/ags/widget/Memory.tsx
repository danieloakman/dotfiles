import { createPoll } from 'ags/time';
import Icon from '../components/Icon';

export const memoryUsage = createPoll('', 1000, 'free').as((str) => {
  const lines = str.split('\n');
  const memLine = lines.find((line) => line.startsWith('Mem:'));
  if (!memLine) return 0;

  const memValues = memLine.split(/\s+/).slice(1).map(Number);
  const total = memValues[0] ?? 0;
  const used = memValues[1] ?? 0;
  // const free = memValues[2];
  // const shared = memValues[3];
  // const buffCache = memValues[4];
  // const available = memValues[5];

  return Math.round((used / total) * 100);
});

export default function Memory() {
  const label = memoryUsage.as((usage) => `${usage}%`);
  return (
    <button name="memory">
      <box spacing={2}>
        <Icon name="memory-stick" />
        <label label={label} widthChars={2} />
      </box>
    </button>
  );
}
