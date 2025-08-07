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
import Media from './Media';

export default function Bar(gdkmonitor: Gdk.Monitor) {
  const { TOP, LEFT, RIGHT } = Astal.WindowAnchor;

  return (
    <window
      visible
      name="bar"
      class="Bar"
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.EXCLUSIVE}
      anchor={TOP | LEFT | RIGHT}
      application={app}
    >
      <centerbox cssName="centerbox">
        <box class="start-box" $type="start" halign={Gtk.Align.START}>
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
        </box>
      </centerbox>
    </window>
  );
}
