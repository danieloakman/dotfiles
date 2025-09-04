import { execAsync } from 'ags/process';
import { Gtk } from 'ags/gtk4';
import Icon from '../components/Icon';
import { classes } from '../utils/styles';
import { notify } from '@/utils/notifications';

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
          <button label="Shutdown" onClicked={() => execAsync('shutdown -P now')} />
          <button label="Suspend" onClicked={() => execAsync('systemctl suspend')} />
          <button label="Reboot" onClicked={() => execAsync('reboot')} />
          <button label="Logout" onClicked={() => execAsync('logout')} />
        </box>
      </popover>
    </menubutton>
  );
}
