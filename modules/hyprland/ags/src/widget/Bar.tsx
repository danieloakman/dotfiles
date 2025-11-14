import app from 'ags/gtk4/app';
import { Astal, Gdk, Gtk } from 'ags/gtk4';
import Clock from './Clock';
import Workspaces from './Workspaces';
import OnscreenKeyboard from './OnscreenKeyboard';
import OSMonitoring from './OSMonitoring';
import { ControlCenterButton } from './ControlCenter';
import { WINDOW_NAME } from '@/utils/window';
import { PasswordSearchButton } from './PasswordSearch';
import { AppsButton } from './Apps';
import { classes } from '@/utils/styles';
import Orientation from './Orientation';
import { Accessor, createExternal } from 'ags';
import HorizontalRevealer from '@/components/HorizontalRevealer';
import { noop } from '@/js-utils';
import { hasTouchDevice } from '@/utils/hyprland';
import MoveMouse from './MoveMouse';

export interface BarProps {
  monitor: Gdk.Monitor | Accessor<Gdk.Monitor>;
}

export default function Bar({ monitor }: BarProps) {
  const { TOP, LEFT, RIGHT } = Astal.WindowAnchor;

  return (
    <window
      visible
      name={WINDOW_NAME.Bar}
      cssClasses={classes('bg-bg-color', 'color-fg-color', 'p-sm', 'opacity-90')}
      gdkmonitor={monitor}
      exclusivity={Astal.Exclusivity.EXCLUSIVE}
      anchor={TOP | LEFT | RIGHT}
      application={app}
    >
      <centerbox name="bar-container" cssName="centerbox">
        <box name="start" $type="start" spacing={4}>
          <HorizontalRevealer
            visible={createExternal(false, (set) => {
              hasTouchDevice().then(set);
              return noop;
            })}
          >
            <OnscreenKeyboard />
            <Orientation />
          </HorizontalRevealer>
          <Workspaces />
          <MoveMouse />
          <AppsButton />
          {/* <Media /> */}
          <PasswordSearchButton />
        </box>

        <box name="center" $type="center" spacing={4}>
          <Clock />
        </box>

        <box name="end" $type="end" spacing={4} halign={Gtk.Align.END}>
          <OSMonitoring />
          <ControlCenterButton />
        </box>
      </centerbox>
    </window>
  );
}
