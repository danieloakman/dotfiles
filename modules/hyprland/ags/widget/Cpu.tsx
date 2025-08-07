import { createPoll } from 'ags/time';
import { Gtk } from 'ags/gtk4';
import Icon from '../components/Icon';

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
  if (!idle) throw new Error('idle is undefined');
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

  return usage;
});

export default function Cpu() {
  const label = cpuUsage.as((stats) => `${stats}`);
  return (
    <button name="cpu">
      <box spacing={4} halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}>
        <Icon name="cpu" size={18} />
        <label label={label} widthChars={2} />
      </box>
    </button>
  );
}
