import { execAsync } from 'ags/process';
import { createPoll } from 'ags/time';
import { Accessor, createComputed, With } from 'ags';
import Icon from '../components/Icon';

export interface BluetoothDevice {
  name: string;
  macAddress: string;
}

export const connectedBluetoothDevices = createPoll('', 10000, 'bluetoothctl devices Connected').as(
  (str) =>
    str
      .split('\n')
      .filter(Boolean)
      .map((line): BluetoothDevice => {
        line = line.replace('Device ', '').trim();
        const firstSpace = line.indexOf(' ');
        const macAddress = line.slice(0, firstSpace);
        const name = line.slice(firstSpace + 1);
        return { macAddress, name };
      }),
);

export const bluetoothStatus = createPoll('', 5000, 'bluetoothctl show').as((str) => ({
  powered: str.includes('Powered: yes'),
  paired: str.includes('Paired: yes'),
  discoverable: str.includes('Discoverable: yes'),
  discovering: str.includes('Discovering: yes'),
}));

export default function Bluetooth() {
  const dataView = createComputed(
    [bluetoothStatus, connectedBluetoothDevices],
    (a, b) => [a, b] as const,
  );
  return (
    <box>
      <button
        name="bluetooth"
        tooltipText="Open Bluetooth Manager"
        onClicked={() => execAsync('blueman-manager')}
      >
        <With value={dataView}>
          {([status, devices]) => {
            const name = devices[0]?.name;
            return (
              <box spacing={1}>
                {/* TODO: add more icon states for discovering, discoverable, pairing, etc */}
                {status.powered ? <Icon name="bluetooth" /> : <Icon name="bluetooth-off" />}
                {name && <label label={name} />}
              </box>
            );
          }}
        </With>
      </button>
    </box>
  );
}
