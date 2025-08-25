import app from 'ags/gtk4/app';
import { Astal, Gdk, Gtk } from 'ags/gtk4';
import Battery from './Battery';
import Clock from './Clock';
import Volume from './Volume';
import Workspaces, { FocusedClient } from './Workspaces';
import Brightness from './Brightness';
import OnscreenKeyboard from './OnscreenKeyboard';
import OSMonitoring from './OSMonitoring';
import { ControlCenterButton } from './ControlCenter';
import { WINDOW_NAME } from '../utils/window';
import { PasswordSearchButton } from './PasswordSearch';
import { AppsButton } from './Apps';
import { classes } from '../utils/styles';
import { createState } from 'ags';

const o = Gtk.Stack;

export default function Bar(gdkmonitor: Gdk.Monitor) {
  const { TOP, LEFT, RIGHT } = Astal.WindowAnchor;
  const [open, setOpen] = createState(false);

  return (
    <window
      visible
      name={WINDOW_NAME.Bar}
      cssClasses={classes('bg-bg-color', 'color-fg-color', 'font-size-md', 'p-xs', 'opacity-90')}
      gdkmonitor={gdkmonitor}
      exclusivity={Astal.Exclusivity.EXCLUSIVE}
      anchor={TOP | LEFT | RIGHT}
      application={app}
    >
      <centerbox cssName="centerbox">
        <box $type="start" spacing={4}>
          <OnscreenKeyboard />
          <Workspaces />
          <AppsButton />
          {/* <Media /> */}
          <PasswordSearchButton />
        </box>

        <box $type="center" spacing={4}>
          <FocusedClient />
          <Clock />
          <button label="overlay" onClicked={() => setOpen((v) => !v)} />
        </box>

        <box $type="end" spacing={4} halign={Gtk.Align.END}>
          <OSMonitoring />
          <Volume />
          <Brightness />
          <Battery />
          <ControlCenterButton />
        </box>
      </centerbox>
    </window>
  );
}
