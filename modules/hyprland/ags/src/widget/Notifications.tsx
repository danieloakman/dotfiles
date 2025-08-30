import { notifications } from '@/utils/notifications';
import { For } from 'ags';
import { Gtk } from 'ags/gtk4';

export default function Notifications() {
  return (
    <box name="Notifications" orientation={Gtk.Orientation.VERTICAL}>
      <For each={notifications}>
        {(notification) => (
          <box name="Notification">
            <image iconName={notification.appIcon} />
            <label lines={[...notification.body.matchAll(/\n/g)].length}>{notification.body}</label>
          </box>
        )}
      </For>
    </box>
  );
}
