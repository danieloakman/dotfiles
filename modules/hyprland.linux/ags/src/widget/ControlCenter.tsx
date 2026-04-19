import { Gtk } from 'ags/gtk4';
import Volume, { VolumeIndicator } from './Volume';
import Internet, { InternetConnection } from './Internet';
import { Restart, Shutdown, Suspend } from './System';
import Bluetooth, { BluetoothConnection } from './Bluetooth';
import { toggleWindow, WINDOW_NAME } from '../utils/window';
import Modal from '../components/Modal';
import Uptime from './Uptime';
import { classes } from '../utils/styles';
import { Hr } from '@/components/Separators';
import TrayApps from './TrayApps';
import Swaync from './Swaync';
import Brightness from './Brightness';
import { BatteryInfo } from './Battery';

export default function ControlCenter() {
  return (
    <Modal
      name={WINDOW_NAME.ControlCenter}
      cssClasses={classes('bg-transparent')}
      valign={Gtk.Align.START}
      halign={Gtk.Align.END}
      margin_top={20}
      margin_end={20}
      width={400}
      height={500}
      opacity={0.9}
    >
      <box
        cssClasses={classes('bg-bg-color', 'rounded', 'p-md')}
        orientation={Gtk.Orientation.VERTICAL}
        spacing={12}
      >
        <centerbox
          orientation={Gtk.Orientation.HORIZONTAL}
        >
          <box $type="start" spacing={8} valign={Gtk.Align.CENTER}>
            <Uptime />
            <BatteryInfo showPercentage />
          </box>
          <box $type="end" spacing={4} valign={Gtk.Align.CENTER}>
            <Suspend />
            <Restart />
            <Shutdown />
          </box>
        </centerbox>

        <Hr />

        <Volume />
        <Brightness />
        {/* <Internet /> */}
        <Bluetooth />
        {/* <NotificationsList /> */}
      </box>
    </Modal>
  );
}

export function ControlCenterButton() {
  return (
    <box cssClasses={classes('rounded-full', 'bg-selected')}>
      <TrayApps />
      <Swaync cssClasses={['btn-ghost-on-bg']} />

      <button
        cssClasses={classes('rounded-full', 'btn-ghost-on-bg')}
        onClicked={() => toggleWindow('control-center')}
      >
        <box spacing={6}>
          <VolumeIndicator />
          <BluetoothConnection />
          <InternetConnection />
          <BatteryInfo />
        </box>
      </button>
    </box>
  );
}
