import app from 'ags/gtk4/app';
import { Astal, Gdk, Gtk } from 'ags/gtk4';
import { createBinding } from 'ags';
import Battery from './Battery';
import Clock from './Clock';
import Volume from './Volume';
import Workspaces from './Workspaces';
import Cpu from './Cpu';
import Memory from './Memory';
import Wifi from './Wifi';
import System from './System';
import Bluetooth from './Bluetooth';
import Brightness from './Brightness';
import OnscreenKeyboard from './OnscreenKeyboard';
import Icon from '../components/Icon';
import { toggleWindow, WINDOW_NAME } from '../utils/window';
import Modal from '../components/Modal';

export default function ControlCenter() {
  return (
    <Modal name={WINDOW_NAME.ControlCenter} cssClasses={['ControlCenter', 'bg-transparent']}>
      <centerbox
        cssClasses={['container', 'bg-bg-color']}
        orientation={Gtk.Orientation.VERTICAL}
        widthRequest={300}
        heightRequest={500}
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
    <button cssClasses={['rounded']} onClicked={() => toggleWindow('control-center')}>
      <Icon name="power" />
    </button>
  );
}
