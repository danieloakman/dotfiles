import { createPoll } from 'ags/time';
import { Gtk } from 'ags/gtk4';
import Icon from '../components/Icon';
import { clamp } from '@/js-utils';
import { Vr } from '../components/Separators';
import { classes } from '../utils/styles';
import { execAsync } from 'ags/process';
import { raise } from '@/js-utils';

export default function OSMonitoring() {
  return (
    <button
      name="os-monitoring"
      cssClasses={classes('rounded-full')}
      onClicked={() =>
        execAsync('kitty --title "btop" --hold -e "btop"').catch((err) =>
          console.error('Failed to open btop', err),
        )
      }
    >
      <box spacing={8}>
        <Cpu />
        <Vr />
        <Memory />
        {/* <Vr />
          <DownloadSpeed />
          <Vr />
          <UploadSpeed /> */}
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

// Store previous network stats for calculating download speed
let prevRxBytes = 0;
export const downloadSpeed = createPoll('', 1000, 'cat /proc/net/dev').as((str) => {
  const lines = str.split('\n');
  let totalRxBytes = 0;

  // Parse /proc/net/dev - skip header lines and loopback interface
  for (const line of lines) {
    // Skip header lines
    if (line.includes('Inter-|') || line.includes(' face |') || line.trim() === '') {
      continue;
    }

    // Parse interface line: "interface: rx_bytes rx_packets ..."
    const match = line.match(/^\s*(\w+):\s+(\d+)/);
    if (match) {
      const interfaceName = match[1];
      const rxBytes = Number(match[2]);

      // Skip loopback interface
      if (interfaceName !== 'lo') {
        totalRxBytes += rxBytes;
      }
    }
  }

  // Calculate download speed in MBps
  // Poll interval is 1000ms (1 second), so bytes per second = diff
  const diffBytes = totalRxBytes - prevRxBytes;
  const mbps = diffBytes >= 0 ? diffBytes / (1024 * 1024) : 0; // Convert bytes to MB

  // Store current value for next iteration
  prevRxBytes = totalRxBytes;

  // Round to 1 decimal place
  return Math.round(mbps * 10) / 10;
});

// Store previous network stats for calculating upload speed
let prevTxBytes = 0;
export const uploadSpeed = createPoll('', 1000, 'cat /proc/net/dev').as((str) => {
  const lines = str.split('\n');
  let totalTxBytes = 0;

  // Parse /proc/net/dev - skip header lines and loopback interface
  for (const line of lines) {
    // Skip header lines
    if (line.includes('Inter-|') || line.includes(' face |') || line.trim() === '') {
      continue;
    }

    // Parse interface line: "interface: rx_bytes ... tx_bytes ..."
    // Format: interface: rx_bytes rx_packets rx_errs rx_drop rx_fifo rx_frame rx_compressed rx_multicast tx_bytes ...
    const match = line.match(/^\s*(\w+):/);
    if (match) {
      const interfaceName = match[1];

      // Skip loopback interface
      if (interfaceName !== 'lo') {
        // Split by whitespace and get tx_bytes (index 9: after interface name and 8 rx fields)
        const parts = line.split(/\s+/).filter((p) => p.length > 0);
        // parts[0] = "interface:", parts[1-8] = rx fields, parts[9] = tx_bytes
        if (parts.length > 9) {
          const txBytes = Number(parts[9]);
          totalTxBytes += txBytes;
        }
      }
    }
  }

  // Calculate upload speed in MBps
  // Poll interval is 1000ms (1 second), so bytes per second = diff
  const diffBytes = totalTxBytes - prevTxBytes;
  const mbps = diffBytes >= 0 ? diffBytes / (1024 * 1024) : 0; // Convert bytes to MB

  // Store current value for next iteration
  prevTxBytes = totalTxBytes;

  // Round to 1 decimal place
  return Math.round(mbps * 10) / 10;
});

export function DownloadSpeed() {
  const label = downloadSpeed.as((speed) => {
    // Format: show 1 decimal place if < 10, otherwise round to integer
    if (speed < 10) return speed.toFixed(1);
    return Math.round(speed).toString();
  });
  return (
    <box spacing={2}>
      <Icon name="download" />
      <label label={label} widthChars={3} />
    </box>
  );
}

export function UploadSpeed() {
  const label = uploadSpeed.as((speed) => {
    // Format: show 1 decimal place if < 10, otherwise round to integer
    if (speed < 10) return speed.toFixed(1);
    return Math.round(speed).toString();
  });
  return (
    <box spacing={2}>
      <Icon name="upload" />
      <label label={label} widthChars={3} />
    </box>
  );
}
