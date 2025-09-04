import Icon from '@/components/Icon';
import { createBooleanState, UnwrapAccessor } from '@/utils/ags';
import { iife } from '@/utils/fn';
import { clearNotifications, notifications } from '@/utils/notifications';
import { classes } from '@/utils/styles';
import { WINDOW_NAME } from '@/utils/window';
import { Accessor, createBinding, createComputed, For } from 'ags';
import { Astal, Gdk, Gtk } from 'ags/gtk4';
import app from 'ags/gtk4/app';
import { createPoll, interval } from 'ags/time';
import Pango from 'gi://Pango';

const { TOP } = Astal.WindowAnchor;

export function NotificationPopups({ monitor }: { monitor?: Gdk.Monitor | Accessor<Gdk.Monitor> }) {
  return (
    <window
      visible={notifications((n) => n.length > 0)}
      name={WINDOW_NAME.Notifications}
      anchor={TOP}
      exclusivity={Astal.Exclusivity.NORMAL}
      application={app}
      gdkmonitor={monitor}
      margin={8}
      widthRequest={400}
      heightRequest={400}
      cssClasses={classes('bg-transparent')}
    >
      <scrolledwindow hscrollbarPolicy={Gtk.PolicyType.NEVER}>
        <box
          orientation={Gtk.Orientation.VERTICAL}
          spacing={4}
          vexpand
          hexpand
          cssClasses={classes('bg-transparent')}
        >
          <For each={notifications}>
            {(notification) => (
              <box cssClasses={classes('bg-bg-color', 'rounded')}>
                <Notification notification={notification} />
              </box>
            )}
          </For>
        </box>
      </scrolledwindow>
    </window>
  );
}

export function NotificationsList() {
  const nonTransientNotifications = notifications(arr => arr.filter(n => !n.transient));

  return (
    <box name="Notifications" spacing={4} orientation={Gtk.Orientation.VERTICAL}>
      <button label="Clear" onClicked={clearNotifications} />

      <scrolledwindow
        hscrollbarPolicy={Gtk.PolicyType.NEVER}
        cssClasses={classes('border', 'rounded')}
      >
        <box
          orientation={Gtk.Orientation.VERTICAL}
          spacing={4}
          vexpand
          hexpand={false}
          cssClasses={classes('p')}
        >
          <For each={nonTransientNotifications}>
            {(notification) => <Notification notification={notification} />}
          </For>
        </box>
      </scrolledwindow>
    </box>
  );
}
const dateNow = createPoll('', 1000, 'echo').as(() => Date.now());

function Notification({
  notification,
}: {
  notification: UnwrapAccessor<typeof notifications>[number];
}) {
  const [revealed, { toggle: toggleRevealed }] = createBooleanState(false);
  const time = createBinding(notification, 'time');
  const expire = createBinding(notification, 'expireTimeout');
  const timeLeft = createComputed(
    [time, expire, dateNow],
    (time, expire, dateNow) => (time + expire) - dateNow,
  );
  const transient = createBinding(notification, 'transient')

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
        <box orientation={Gtk.Orientation.VERTICAL} spacing={4}>
          <label label={notification.appIcon} />
          <image iconName={notification.appIcon} />
          <label
            lines={3}
            label={[notification.time, notification.summary, notification.body].join('\n')}
          />
          <label label={expire(t => `Expire: ${t} seconds`)} />
          <label label={time(t => `Time: ${t / 1000} seconds`)} />
          <label label={timeLeft((t) => `Time Left: ${t / 1000} seconds`)} />
          <label label={transient(t => `Transient: ${t}`)} />
        </box>
      </revealer>
    </box>
  );
}
