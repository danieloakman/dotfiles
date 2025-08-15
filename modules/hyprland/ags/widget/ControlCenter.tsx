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

export default function ControlCenter(gdkmonitor: Gdk.Monitor) {
  const { TOP, RIGHT } = Astal.WindowAnchor;

  return (
    <window
      name={WINDOW_NAME.ControlCenter}
      class="ControlCenter"
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.NORMAL}
      anchor={TOP | RIGHT}
      application={app}
      $={(self) =>
        self.connect('move-focus', () => {
          console.log('move-focus');
        })
      }
      margin={10}
    >
      <box orientation={Gtk.Orientation.VERTICAL}>
        <button label="hello there"></button>
      </box>
    </window>
  );
}

export function ControlCenterButton() {
  return (
    <button onClicked={() => toggleWindow('control-center')}>
      <Icon name="power" />
    </button>
  );
}
