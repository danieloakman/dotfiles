import { createPoll } from 'ags/time';
import { Gtk } from 'ags/gtk4';
import { With } from 'ags';
import { execAsync } from 'ags/process';
import Icon from '../components/Icon';
import { clamp } from '../utils/number';

const POWER_MODES = ['performance', 'power-saver'] as const;
export type PowerMode = (typeof POWER_MODES)[number];

const BAT_CHARGE: Icon.Name[] = ['battery', 'battery-low', 'battery-medium', 'battery-full'];
const BAT0_PATH = '/sys/class/power_supply/BAT0';
const BATTERY_INTERVAL = 5000;
const POWER_MODE_INTERVAL = 10000;
const POWER_MODE_REGEX = /Mode += +\w+/;
const POWER_MODE_MAP: Record<string, string> = {
  AC: 'performance',
  battery: 'power-saver',
  performance: 'ac',
  'power-saver': 'bat',
};

const powerMode = createPoll('', POWER_MODE_INTERVAL, 'tlp-stat -s').as((res): PowerMode | null => {
  const mode = res.match(POWER_MODE_REGEX)?.[0].split('=')[1]?.trim();
  return mode ? (POWER_MODE_MAP[mode] as PowerMode) ?? null : null;
});

const getBatteryIcon = (chargePercentage: number) => {
  const index = clamp(
    Math.ceil(chargePercentage / (100 / BAT_CHARGE.length)) - 1,
    0,
    BAT_CHARGE.length - 1,
  );
  return BAT_CHARGE[index];
};

export const battery = createPoll(
  '',
  BATTERY_INTERVAL,
  `cat ${BAT0_PATH}/status ${BAT0_PATH}/capacity ${BAT0_PATH}/charge_now ${BAT0_PATH}/charge_full`,
).as((str) => {
  const [status = 'Unknown', ...nums] = str.split('\n').map((v) => v.trim());
  const [percentage = 0, chargeNow = 0, chargeFull = 0] = nums.map((v) => parseInt(v));
  return {
    percentage,
    status: status as 'Charging' | 'Discharging' | 'Full' | 'Unknown',
    chargeNow,
    chargeFull,
    iconName:
      status === 'Charging' ? 'battery-charging' : (getBatteryIcon(percentage) as Icon.Name),
  };
});

export default function Battery() {
  return (
    <menubutton name="battery" hexpand halign={Gtk.Align.CENTER}>
      <With value={battery}>
        {({ iconName, percentage }) => (
          <box spacing={4}>
            <Icon name={iconName} />
            <label label={`${percentage}%`} widthChars={3} />
          </box>
        )}
      </With>

      <popover>
        <With value={powerMode}>
          {(mode) =>
            mode && (
              <box orientation={Gtk.Orientation.VERTICAL} spacing={4}>
                <Gtk.DropDown
                  selected={POWER_MODES.indexOf(mode ?? 'performance')}
                  model={Gtk.StringList.new(POWER_MODES.map((v) => v.toUpperCase()))}
                  onNotifySelectedItem={(s) => {
                    // Would be nice if this started in a floating window.
                    // `hyprctl dispatch exec [floating] kitty ...`, but I couldn't get this to work so far.
                    const mode = POWER_MODE_MAP[POWER_MODES[s.get_selected()] ?? 'performance'];
                    execAsync(
                      `kitty zsh -c "echo 'Enter your password to change to power saver mode.' && sudo tlp ${mode}"`,
                    ).catch(console.error);
                  }}
                />
              </box>
            )
          }
        </With>
      </popover>
    </menubutton>
  );
}

export { powerMode };
