import { Gtk } from 'ags/gtk4';
import Volume, { VolumeIndicator } from './Volume';
import Internet, { InternetConnection } from './Internet';
import System from './System';
import Bluetooth, { BluetoothConnection } from './Bluetooth';
import { toggleWindow, WINDOW_NAME } from '../utils/window';
import Modal from '../components/Modal';
import Uptime from './Uptime';
import { classes } from '../utils/styles';

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
        cssClasses={classes('bg-bg-color', 'rounded-md', 'p-md')}
        orientation={Gtk.Orientation.VERTICAL}
        vexpand
        hexpand
        spacing={4}
      >
        <centerbox
          orientation={Gtk.Orientation.HORIZONTAL}
          cssClasses={classes('border', 'rounded-sm', 'p-xs')}
        >
          <box $type="start" spacing={4} valign={Gtk.Align.CENTER}>
            <Uptime />
          </box>
          <box $type="end" spacing={4} valign={Gtk.Align.CENTER}>
            <System />
          </box>
        </centerbox>

        <Volume />
        <Internet />
        <Bluetooth />
      </box>
    </Modal>
  );
}

export function ControlCenterButton() {
  return (
    <button cssClasses={classes('rounded-full')} onClicked={() => toggleWindow('control-center')}>
      <box spacing={6}>
        <VolumeIndicator />
        <BluetoothConnection />
        <InternetConnection />
      </box>
    </button>
  );
}
