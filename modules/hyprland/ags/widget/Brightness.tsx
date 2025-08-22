import { Accessor, createExternal, With } from 'ags';
import { execAsync } from 'ags/process';
import { noop } from '../utils/fn';
import { createExternalState } from '../utils/ags';
import Icon from '../components/Icon';
import GObject from 'gi://GObject?version=2.0';

export const maxBrightness = createExternal(900, (set) => {
  execAsync('brightnessctl max').then((stdout) => {
    set(parseInt(stdout.trim()));
  });
  return noop;
});

const [currentBrightness, setCurrentBrightness] = createExternalState<number>(0, (set) => {
  execAsync('brightnessctl get').then((stdout) => {
    set(parseInt(stdout.trim()));
  });
  return noop;
});

export default function Brightness() {
  return (
    <box>
      <With value={maxBrightness}>
        {(max) => {
          const step = Math.ceil(max / 100);
          const min = Math.ceil(max * 0.05);
          if (min === max) return null;
          return (
            <menubutton name="brightness">
              <Icon name="sun" />

              <popover>
                <BrightnessCtrl min={min} max={max} step={step} />
              </popover>
            </menubutton>
          );
        }}
      </With>
    </box>
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
