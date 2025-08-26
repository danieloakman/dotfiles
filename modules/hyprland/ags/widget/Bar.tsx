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

export interface BarProps {
  monitor: Gdk.Monitor;
}

export default function Bar({ monitor }: BarProps) {
  const { TOP, LEFT, RIGHT } = Astal.WindowAnchor;

  return (
    <window
      visible
      name={WINDOW_NAME.Bar}
      cssClasses={classes('bg-bg-color', 'color-fg-color', 'font-size-md', 'p-xs', 'opacity-90')}
      gdkmonitor={monitor}
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
        </box>

        <box $type="end" spacing={4} halign={Gtk.Align.END}>
          <OSMonitoring />
          <Brightness />
          <Battery />
          <ControlCenterButton />
        </box>
      </centerbox>
    </window>
  );
}
