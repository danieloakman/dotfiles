import app from 'ags/gtk4/app';
import { Astal, Gdk, Gtk } from 'ags/gtk4';
import { createBinding } from 'ags';
import Battery from './Battery';
import Clock from './Clock';
import Volume from './Volume';
import Workspaces from './Workspaces';
import Cpu from './Cpu';
import Memory from './Memory';
import Internet, { InternetConnection } from './Internet';
import System from './System';
import Bluetooth, { BluetoothConnection } from './Bluetooth';
import Brightness from './Brightness';
import OnscreenKeyboard from './OnscreenKeyboard';
import Icon from '../components/Icon';
import { toggleWindow, WINDOW_NAME } from '../utils/window';
import Modal from '../components/Modal';
import Uptime from './Uptime';

export default function ControlCenter() {
  return (
    <Modal
      name={WINDOW_NAME.ControlCenter}
      cssClasses={['ControlCenter', 'bg-transparent']}
      valign={Gtk.Align.START}
      halign={Gtk.Align.END}
      margin_top={20}
      margin_end={20}
      width={400}
      height={500}
      transitionType={Gtk.RevealerTransitionType.CROSSFADE}
    >
      <centerbox
        cssClasses={['container', 'bg-bg-color', 'rounded-md', 'p-md']}
        orientation={Gtk.Orientation.VERTICAL}
        vexpand
        hexpand
      >
        <centerbox $type="start" orientation={Gtk.Orientation.HORIZONTAL}>
          <box $type="start" spacing={4} valign={Gtk.Align.CENTER}>
            <Uptime />
          </box>
          <box $type="end" spacing={4} valign={Gtk.Align.CENTER}>
            <System />
          </box>
        </centerbox>
      </centerbox>
    </Modal>
  );
}

export function ControlCenterButton() {
  return (
    <button cssClasses={['rounded-full']} onClicked={() => toggleWindow('control-center')}>
      <box spacing={6}>
        <InternetConnection />
        <BluetoothConnection />
      </box>
    </button>
  );
}
