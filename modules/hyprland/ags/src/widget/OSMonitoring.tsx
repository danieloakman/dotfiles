import { createPoll } from 'ags/time';
import { Gtk } from 'ags/gtk4';
import Icon from '../components/Icon';
import { clamp } from '../utils/number';
import { Vr } from '../components/Separators';
import { classes } from '../utils/styles';
import { execAsync } from 'ags/process';
import { raise } from '@/utils/fn';

export default function OSMonitoring() {
  return (
    <button
      name="os-monitoring"
      cssClasses={classes('rounded-full')}
      onClicked={() => execAsync('kitty --title "btop" --hold -e "btop"')}
    >
      <box spacing={8}>
        <Cpu />
        <Vr />
        <Memory />
      </box>
    </button>
  );
}

// Based on script from: https://www.mail-archive.com/linuxkernelnewbies@googlegroups.com/msg01690.html
// Store previous CPU stats for calculating usage
let prevTotal = 0;
let prevIdle = 0;
export const cpuUsage = createPoll('', 1000, 'cat /proc/stat').as((str) => {
  const lines = str.split('\n');
  const cpuLine = lines.find((line) => line.startsWith('cpu '));

  if (!cpuLine) return 0;

  // Parse CPU stats: user nice system idle iowait irq softirq steal guest guest_nice
  const cpuValues = cpuLine.split(/\s+/).slice(1).map(Number);
  const idle = cpuValues[3]; // idle time is at index 3
  if (!idle) raise('idle is undefined');
  const total = cpuValues.reduce((sum, value) => sum + value, 0);

  // Calculate CPU usage since last check
  const diffIdle = idle - prevIdle;
  const diffTotal = total - prevTotal;

  // Calculate percentage with rounding
  const usage =
    diffTotal > 0 ? Math.round(((1000 * (diffTotal - diffIdle)) / diffTotal + 5) / 10) : 0;

  // Store current values for next iteration
  prevTotal = total;
  prevIdle = idle;

  return clamp(usage, 0, 100);
});

export function Cpu() {
  const label = cpuUsage.as((stats) => `${stats}`);
  return (
    <box spacing={4} halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}>
      <Icon name="cpu" size={18} />
      <label label={label} widthChars={2} />
    </box>
  );
}

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

export function Memory() {
  return (
    <box spacing={2}>
      <Icon name="memory-stick" />
      <label label={memoryUsage((n) => n.toString())} widthChars={2} />
    </box>
  );
}
