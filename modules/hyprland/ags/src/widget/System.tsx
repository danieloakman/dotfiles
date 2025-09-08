import { execAsync } from 'ags/process';
import { Gtk } from 'ags/gtk4';
import Icon from '../components/Icon';
import { classes } from '../utils/styles';
import { notify } from '@/utils/notifications';
import { hideAllWindows } from '@/utils/window';

export default function System() {
  return (
    <menubutton
      halign={Gtk.Align.CENTER}
      valign={Gtk.Align.CENTER}
      tooltipText="System Options"
      cssClasses={classes('circular')}
    >
      <box halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}>
        <Icon name="power" />
      </box>

      <popover vexpand hexpand>
        <box spacing={4} orientation={Gtk.Orientation.VERTICAL}>
          <button
            label="Shutdown"
            onClicked={async () => {
              hideAllWindows();
              const { action } = await notify({
                summary: 'Shutdown',
                body: 'Are you sure you want to shutdown?',
                actions: { confirm: 'Confirm', cancel: 'Cancel' },
                transient: true,
                icon: 'emblem-system-symbolic',
              });
              if (action === 'confirm') execAsync('shutdown -P now');
            }}
          />
          <button
            label="Suspend"
            onClicked={() => {
              execAsync('systemctl suspend');
            }}
          />
          <button label="Reboot" onClicked={() => execAsync('reboot')} />
          <button label="Logout" onClicked={() => execAsync('logout')} />
        </box>
      </popover>
    </menubutton>
  );
}

export function Shutdown() {
  return (
    <button
      cssClasses={classes('circular')}
      tooltipText="Shutdown"
      onClicked={async () => {
        hideAllWindows();
        const { action } = await notify({
          summary: 'Shutdown',
          body: 'Are you sure you want to shutdown?',
          actions: { confirm: 'Confirm', cancel: 'Cancel' },
          transient: true,
          icon: 'emblem-system-symbolic',
        });
        if (action === 'confirm') execAsync('shutdown -P now');
      }}
    >
      <box halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}>
        <Icon name="power" />
      </box>
    </button>
  );
}

export function Suspend() {
  return (
    <button
      cssClasses={classes('circular')}
      tooltipText="Suspend"
      onClicked={() => execAsync('systemctl suspend')}
    >
      <box halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}>
        <Icon name="lock" />
      </box>
    </button>
  );
}

export function Restart() {
  return (
    <button
      cssClasses={classes('circular')}
      tooltipText="Restart"
      onClicked={async () => {
        hideAllWindows();
        const { action } = await notify({
          summary: 'Restart',
          body: 'Are you sure you want to restart?',
          actions: { confirm: 'Confirm', cancel: 'Cancel' },
          transient: true,
          icon: 'emblem-system-symbolic',
        });
        if (action === 'confirm') execAsync('reboot');
      }}
    >
      <box halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}>
        <Icon name="rotate-ccw" />
      </box>
    </button>
  );
}
