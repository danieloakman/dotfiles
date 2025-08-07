import { Accessor, createComputed, createExternal } from 'ags';
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

export interface BrightnessProps {
  width?: number | Accessor<number>;
}

export default function Brightness() {
  return (
    <menubutton name="brightness">
      <Icon name="sun" />

      <popover>
        <BrightnessCtrl />
      </popover>
    </menubutton>
  );
}

function BrightnessCtrl({ width = 150 }: BrightnessProps) {
  const step = createComputed([maxBrightness], (max) => Math.ceil(max / 100));
  const min = createComputed([maxBrightness], (max) => Math.ceil(max * 0.05));

  return (
    <slider
      value={currentBrightness}
      width_request={width}
      min={min}
      max={maxBrightness}
      step={step}
      onChangeValue={({ value }) => {
        execAsync(`brightnessctl set ${value}`);
        setCurrentBrightness(value);
      }}
    />
  );
}
