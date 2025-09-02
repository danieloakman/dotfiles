import Icon from '@/components/Icon';
import { createBooleanState, UnwrapAccessor } from '@/utils/ags';
import { clearNotifications, notifications } from '@/utils/notifications';
import { classes } from '@/utils/styles';
import { WINDOW_NAME } from '@/utils/window';
import { Accessor, For, onMount } from 'ags';
import { Astal, Gdk, Gtk } from 'ags/gtk4';
import app from 'ags/gtk4/app';
import Pango from 'gi://Pango';

export function NotificationPopups({ monitor }: { monitor?: Gdk.Monitor | Accessor<Gdk.Monitor> }) {
  const { TOP, BOTTOM, RIGHT, LEFT } = Astal.WindowAnchor;
  return (
    <window
      // visible={notifications((n) => n.length > 0)}
      name={WINDOW_NAME.Notifications}
      anchor={TOP | RIGHT}
      exclusivity={Astal.Exclusivity.NORMAL}
      application={app}
      gdkmonitor={monitor}
    >
      <box>
        <label label="Notifications TODO" />
      </box>
    </window>
  );
}

export function NotificationsList() {
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
