import { createPoll } from 'ags/time';
import { Gtk } from 'ags/gtk4';
import { createExternal, With } from 'ags';
import { execAsync } from 'ags/process';
import Icon from '../components/Icon';
import { clamp } from '../utils/number';
import { noop } from '../utils/fn';
import DropDownSelect from '../components/DropDownSelect';

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
const getBatteryIcon = (chargePercentage: number) => {
  const index = clamp(
    Math.ceil(chargePercentage / (100 / BAT_CHARGE.length)) - 1,
    0,
    BAT_CHARGE.length - 1,
  );
  return BAT_CHARGE[index];
};

export const hasBattery = createExternal(false, (set) => {
  execAsync(`ls ${BAT0_PATH}`)
    .then(() => set(true))
    .catch(() => set(false));
  return noop;
});

export const powerMode = createPoll('', POWER_MODE_INTERVAL, 'tlp-stat -s').as(
  (res): PowerMode | null => {
    const mode = res.match(POWER_MODE_REGEX)?.[0].split('=')[1]?.trim();
    return mode ? (POWER_MODE_MAP[mode] as PowerMode) ?? null : null;
  },
);

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
// const lastCharges: { timestamp: number; charge: number }[] = [];
// const LAST_CHARGES_LIMIT = 5;
// const deltaCharge = () => {
//   if (lastCharges.length < 2) return 0;
//   const deltas: number[] = [];
//   for (let i = 0; i < lastCharges.length - 1; i++) {
//     const last = lastCharges[i];
//     const next = lastCharges[i + 1];
//     if (!last || !next) continue;
//     deltas.push(last.charge - next.charge);
//   }
//   return deltas.reduce((a, b) => a + b, 0) / deltas.length;
// };
// export const chargeTimeRemaining = battery.as(({ chargeNow, chargeFull }) => {
//   if (chargeNow) lastCharges.push({ charge: chargeNow, timestamp: Date.now() });
//   while (lastCharges.length >= LAST_CHARGES_LIMIT) lastCharges.shift();
//   const delta = deltaCharge();
//   if (delta === 0) return 0;
//   const deltaPerSecond = delta / (BATTERY_INTERVAL / 1000);
//   if (deltaPerSecond < 0) {
//     return chargeNow / -deltaPerSecond; // discharging
//   } else {
//     return (chargeFull - chargeNow) / deltaPerSecond; // charging
//   }
// });

export default function Battery() {
  return (
    <box visible={hasBattery}>
      <With value={hasBattery}>
        {(hasBattery) => {
          if (!hasBattery) return null;
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
                        {/* <With value={chargeTimeRemaining}>
                  {(seconds) => (<label label={`${seconds}s`} />)}
                </With> */}
                        <DropDownSelect
                          options={POWER_MODES}
                          selected={mode}
                          onSelected={(newMode) => {
                            // Would be nice if this started in a floating window.
                            // `hyprctl dispatch exec [floating] kitty ...`, but I couldn't get this to work so far.
                            if (newMode === mode) return;
                            console.error('power mode switch not implemented');
                            // execAsync(
                            //   `kitty zsh -c "echo 'Enter your password to change to power saver mode.' && sudo tlp ${POWER_MODE_MAP[newMode]}"`,
                            // ).catch(console.error);
                          }}
                        />
                      </box>
                    )
                  }
                </With>
              </popover>
            </menubutton>
          );
        }}
      </With>
    </box>
  );
}
