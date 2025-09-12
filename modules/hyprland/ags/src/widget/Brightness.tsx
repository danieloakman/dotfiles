import { Accessor, createComputed, createExternal, With } from 'ags';
import { execAsync } from 'ags/process';
import { debounce, noop } from '../utils/fn';
import { createExternalState } from '../utils/ags';
import Icon from '../components/Icon';
import Card from '@/components/Card';
import { Gtk } from 'ags/gtk4';
import { classes } from '@/utils/styles';

export const maxBrightness = createExternal(900, (set) => {
  execAsync('brightnessctl max').then((stdout) => {
    set(parseInt(stdout.trim()));
  });
  return noop;
});

const [currentBrightness, setCurrentBrightness] = createExternalState<number>(0, (set) => {
  Promise.all([
    execAsync('brightnessctl get').then((stdout) => parseInt(stdout.trim())),
    execAsync('brightnessctl max').then((stdout) => parseInt(stdout.trim())),
  ])
    .then(([brightness, max]) => {
      set((brightness / max) * 100);
    })
    .catch((err) => {
      console.error('brightness get error', err);
    });
  return noop;
});
export { currentBrightness as brightness };

const canControlBrightness = maxBrightness((max) => {
  const min = Math.ceil(max * 0.05);
  return min !== max;
});

/** Set the brightness to a value between 0 and 100. */
export const setBrightness = debounce(async (value: number) => {
  await execAsync(`swayosd-client --brightness ${value}`).catch((err) =>
    console.error('brightness set error', err),
  );
  setCurrentBrightness(value);
}, 100);

export default function Brightness() {
  return (
    <Card
      name="Brightness"
      visible={canControlBrightness}
      hexpand
      orientation={Gtk.Orientation.HORIZONTAL}
      spacing={4}
    >
      <button
        cssClasses={classes('btn-ghost', 'rounded-full')}
        onClicked={() => (currentBrightness.get() === 100 ? setBrightness(1) : setBrightness(100))}
      >
        <Icon name="sun" />
      </button>
      <slider
        value={currentBrightness}
        min={1}
        max={100}
        step={1}
        onChangeValue={({ value }) => setBrightness(Math.round(value))}
        hexpand
      />
    </Card>
  );
}

function BrightnessCtrl({
  width = 150,
  max,
  min,
  step,
}: {
  width?: number | Accessor<number>;
  min?: number | Accessor<number>;
  max?: number | Accessor<number>;
  step?: number | Accessor<number>;
}) {
  return (
    <slider
      value={currentBrightness}
      width_request={width}
      min={min}
      max={max}
      step={step}
      onChangeValue={({ value }) => {
        execAsync(`brightnessctl set ${value}`);
        setCurrentBrightness(value);
      }}
    />
  );
}
