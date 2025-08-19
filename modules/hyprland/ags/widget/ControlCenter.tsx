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
import Bluetooth from './Bluetooth';
import Brightness from './Brightness';
import OnscreenKeyboard from './OnscreenKeyboard';
import Icon from '../components/Icon';
import { toggleWindow, WINDOW_NAME } from '../utils/window';
import Modal from '../components/Modal';

export default function ControlCenter() {
  return (
    <Modal
      name={WINDOW_NAME.ControlCenter}
      cssClasses={['ControlCenter', 'bg-transparent']}
      valign={Gtk.Align.START}
      halign={Gtk.Align.END}
      margin_top={20}
      margin_end={20}
      width={300}
      height={500}
      transitionType={Gtk.RevealerTransitionType.CROSSFADE}
    >
      <centerbox
        cssClasses={['container', 'bg-bg-color', 'rounded-md']}
        orientation={Gtk.Orientation.VERTICAL}
        vexpand
        hexpand
      >
        <box $type="start" orientation={Gtk.Orientation.VERTICAL}>
          <label label="hello there" />
        </box>
      </centerbox>
    </Modal>
  );
}

export function ControlCenterButton() {
  return (
    <button cssClasses={['rounded-full']} onClicked={() => toggleWindow('control-center')}>
      <InternetConnection />
    </button>
  );
}
