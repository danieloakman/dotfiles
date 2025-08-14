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

const CONTROL_CENTER_WINDOW_NAME = 'control-center';

export function showControlCenter() {
  console.log('showControlCenter');
  app.get_window(CONTROL_CENTER_WINDOW_NAME)?.show();
}

export function hideControlCenter() {
  console.log('hideControlCenter');
  app.get_window(CONTROL_CENTER_WINDOW_NAME)?.hide();
}

export function isControlCenterVisible() {
  return app.get_window(CONTROL_CENTER_WINDOW_NAME)?.is_visible();
}

export function toggleControlCenter() {
  if (isControlCenterVisible()) {
    hideControlCenter();
  } else {
    showControlCenter();
  }
}

export default function ControlCenter(gdkmonitor: Gdk.Monitor) {
  const { TOP, RIGHT } = Astal.WindowAnchor;

  return (
    <window
      name={CONTROL_CENTER_WINDOW_NAME}
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
    <button onClicked={toggleControlCenter}>
      <Icon name="power" />
    </button>
  );
}
