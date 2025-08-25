import { Accessor, createExternal, With } from 'ags';
import { execAsync } from 'ags/process';
import { noop } from '../utils/fn';
import { createExternalState } from '../utils/ags';
import Icon from '../components/Icon';

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

const canControlBrightness = maxBrightness(max => {
  const min = Math.ceil(max * 0.05);
  return min !== max;
})

export default function Brightness() {
  return (
    <box visible={canControlBrightness}>
      <With value={maxBrightness}>
        {(max) => {
          const step = Math.ceil(max / 100);
          const min = Math.ceil(max * 0.05);
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
