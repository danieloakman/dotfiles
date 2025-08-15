import app from 'ags/gtk4/app';
import { Astal, Gdk, Gtk } from 'ags/gtk4';
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
import { ControlCenterButton } from './ControlCenter';
import { WINDOW_NAME } from '../utils/window';

export default function Bar(gdkmonitor: Gdk.Monitor) {
  const { TOP, LEFT, RIGHT } = Astal.WindowAnchor;

  return (
    <window
      visible
      name={WINDOW_NAME.Bar}
      class="Bar"
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.EXCLUSIVE}
      anchor={TOP | LEFT | RIGHT}
      application={app}
    >
      <centerbox cssName="centerbox">
        <box class="start-box" $type="start" spacing={4} halign={Gtk.Align.START}>
          <OnscreenKeyboard />
          <Workspaces />
          {/* <Media /> */}
        </box>

        <box class="end-box" $type="end" halign={Gtk.Align.END}>
          <Cpu />
          <Memory />
          <Wifi />
          <Bluetooth />
          <Volume />
          <Brightness />
          <Battery />
          <Clock />
          <System />
          <ControlCenterButton />
        </box>
      </centerbox>
    </window>
  );
}
