import Icon from '@/components/Icon';
import { createBooleanState, createInterval, UnwrapAccessor } from '@/utils/ags';
import { iife } from '@/utils/fn';
import { clearNotifications, notifications } from '@/utils/notifications';
import { classes } from '@/utils/styles';
import { WINDOW_NAME } from '@/utils/window';
import { Accessor, createBinding, createComputed, createExternal, For } from 'ags';
import { Astal, Gdk, Gtk } from 'ags/gtk4';
import app from 'ags/gtk4/app';
import { createPoll, interval } from 'ags/time';
import Pango from 'gi://Pango';
import Notifd from 'gi://AstalNotifd';
import { StyleClass } from '@/types/style-classes';
import { clamp } from '@/utils/number';

Gtk.LevelBar;

const { TOP } = Astal.WindowAnchor;

const URGENCY_COLORS: Record<Notifd.Urgency, string> = {
  [Notifd.Urgency.CRITICAL]: 'red',
  [Notifd.Urgency.NORMAL]: '$fg-color',
  [Notifd.Urgency.LOW]: '$selected',
};

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
              <Notification
                notification={notification}
                cssClasses={['bg-bg-color', 'rounded', 'px']}
              />
            )}
          </For>
        </box>
      </scrolledwindow>
    </window>
  );
}

export function NotificationsList() {
  const nonTransientNotifications = notifications((arr) => arr.filter((n) => !n.transient));

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

const UPDATE_INTERVAL = 50;
const DEFAULT_TIMEOUT = 10000;

function Notification({
  notification,
  width = 500,
  cssClasses = [],
  css = '',
}: {
  notification: UnwrapAccessor<typeof notifications>[number];
  width?: number;
  cssClasses?: StyleClass[];
  css?: string;
}) {
  const [revealed, { toggle: toggleRevealed }] = createBooleanState(false);
  const time = createBinding(notification, 'time').as((t) => t * 1000);
  // const expire = createBinding(notification, 'expireTimeout');
  const appName = createBinding(notification, 'appName');
  const appIcon = createBinding(notification, 'appIcon');
  const interval = createInterval(UPDATE_INTERVAL);
  const levelMaxValue =
    notification.expireTimeout < 0 ? DEFAULT_TIMEOUT : notification.expireTimeout;
  const levelValue = interval((t) => clamp(t * UPDATE_INTERVAL, 0, levelMaxValue));

  return (
    <box
      name="Notification"
      orientation={Gtk.Orientation.VERTICAL}
      cssClasses={classes('p-xs', ...cssClasses)}
      widthRequest={width}
      hexpand
      css={`
        ${css}
        border-left-width: 4px;
        border-left-style: solid;
        border-color: ${URGENCY_COLORS[notification.urgency]};
      `}
    >
      <centerbox valign={Gtk.Align.CENTER} hexpand widthRequest={width}>
        <box $type="start" spacing={6}>
          <Icon name="bell" />

          <box spacing={4} orientation={Gtk.Orientation.VERTICAL} valign={Gtk.Align.CENTER}>
            <label
              lines={1}
              label={appName}
              ellipsize={Pango.EllipsizeMode.END}
              halign={Gtk.Align.START}
              cssClasses={classes('opacity-70')}
            />
            <label
              lines={1}
              label={notification.summary}
              ellipsize={Pango.EllipsizeMode.END}
              halign={Gtk.Align.START}
              cssClasses={classes('font-size-lg')}
            />

            <label
              visible={!!notification.body}
              lines={1}
              label={notification.body}
              ellipsize={Pango.EllipsizeMode.END}
              halign={Gtk.Align.START}
              cssClasses={classes('opacity-70')}
            />
          </box>
        </box>

        <box $type="end" spacing={4} marginStart={6} valign={Gtk.Align.CENTER}>
          <label
            label={time((t) => {
              const [h, m] = new Date(t).toLocaleTimeString().split(':').slice(0, 2);
              const hours = parseInt(h ?? '0');
              return `${(hours % 12)?.toString().padStart(2, '0')}:${m?.padStart(2, '0')}${
                hours >= 12 ? 'pm' : 'am'
              }`;
            })}
          />
          <button onClicked={() => notification.dismiss()} cssClasses={classes('btn-ghost')}>
            <Icon name="x" />
          </button>
          <button onClicked={toggleRevealed}>
            <Icon name={revealed((v) => (v ? 'chevron-down' : 'chevron-right'))} />
          </button>
        </box>
      </centerbox>

      <levelbar
        value={levelValue}
        maxValue={levelMaxValue}
        minValue={0}
        heightRequest={1}
        // levelbar[.discrete]
        // ╰── trough
        //     ├── block.filled.level-name
        //     ┊
        //     ├── block.empty
        //     ┊
        // css={`
        //   color: red;
        //   * {
        //     color: transparent;
        //     background-color: transparent;
        //   }
        //   transition: all 0.5s ease-in-out;
        //   trough {
        //     background-color: transparent;
        //   }
        //   block.filled {
        //     background-color: ${URGENCY_COLORS[notification.urgency]};
        //   }
        //   block.empty {
        //     background-color: transparent;
        //   }
        // `}
      />

      <revealer revealChild={revealed} widthRequest={width}>
        <box orientation={Gtk.Orientation.VERTICAL} spacing={4} valign={Gtk.Align.CENTER}>
          <label label={`Desktop Entry: ${notification.desktopEntry}`} />
          <label label={`App Name: ${notification.appName}`} />
          <label label={`App Icon: ${notification.appIcon}`} />
          {/* <label label={`Time: ${notification.time}`} /> */}
          <label label={`Expire: ${notification.expireTimeout}`} />
          <label label={`Transient: ${notification.transient}`} />
          <image file={notification.image} />
          <label label={`a ${notification.image}`} />
          {/* <label label={notification.appIcon} />
          <image iconName={notification.appIcon} />
          <label
            lines={3}
            label={[notification.time, notification.summary, notification.body].join('\n')}
          />
          <label label={expire((t) => `Expire: ${t} seconds`)} />
          <label label={time((t) => `Time: ${t / 1000} seconds`)} />
          <label label={timeLeft((t) => `Time Left: ${t / 1000} seconds`)} />
          <label label={transient((t) => `Transient: ${t}`)} /> */}
        </box>
      </revealer>
    </box>
  );
}
