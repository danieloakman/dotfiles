import Icon from '@/components/Icon';
import { createBooleanState, UnwrapAccessor } from '@/utils/ags';
import { clearNotifications, notifications } from '@/utils/notifications';
import { classes } from '@/utils/styles';
import { For, onMount } from 'ags';
import { Gtk } from 'ags/gtk4';
import Pango from 'gi://Pango';

export default function Notifications() {
  return (
    <box name="Notifications" spacing={4} orientation={Gtk.Orientation.VERTICAL}>
      <button label="Clear" onClicked={clearNotifications} />

      <scrolledwindow
        hscrollbarPolicy={Gtk.PolicyType.NEVER}
        cssClasses={classes('border', 'rounded-md')}
      >
        <box
          orientation={Gtk.Orientation.VERTICAL}
          spacing={4}
          vexpand
          hexpand={false}
          cssClasses={classes('p-md')}
        >
          <For each={notifications}>
            {(notification) => <Notification notification={notification} />}
          </For>
        </box>
      </scrolledwindow>
    </box>
  );
}

function Notification({
  notification,
}: {
  notification: UnwrapAccessor<typeof notifications>[number];
}) {
  const [revealed, { toggle: toggleRevealed }] = createBooleanState(false);
  return (
    <box name="Notification" orientation={Gtk.Orientation.VERTICAL}>
      <box spacing={4}>
        <Icon name="bell" />
        <label
          label={notification.summary}
          ellipsize={Pango.EllipsizeMode.END}
          maxWidthChars={20}
        />
        <button onClicked={() => notification.dismiss()} cssClasses={classes('btn-ghost')}>
          <Icon name="x" />
        </button>
        <button onClicked={toggleRevealed}>
          <Icon name={revealed((v) => (v ? 'chevron-down' : 'chevron-right'))} />
        </button>
      </box>

      <revealer revealChild={revealed}>
        <label label={notification.appIcon} />
        <image iconName={notification.appIcon} />
        <label
          lines={3}
          label={[notification.time, notification.summary, notification.body].join('\n')}
        />
      </revealer>
    </box>
  );
}
