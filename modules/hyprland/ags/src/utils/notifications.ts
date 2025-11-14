import { NativeIcon } from '@/types/icons';
import { createState } from 'ags';
import { execAsync, createSubprocess } from 'ags/process';
import { safeJSONParse } from '@/js-utils';
import { raise } from '@/js-utils';

// ***ASTAL NOTIFD IMPLEMENTATION***
// import Notifd from 'gi://AstalNotifd';
// const notifd = Notifd.get_default();
const [astalNotifications] = createState<import('gi://AstalNotifd').default.Notification[]>([]);
export { astalNotifications };
// export const notifications = createBinding(notifd, 'notifications').as((notifications) => {
//   // Dismiss duplicate notifications
//   const results = new Map<string, Notifd.Notification>();
//   for (const notification of notifications) {
//     const key = notification.get_app_name() + notification.get_summary() + notification.get_body();
//     if (results.has(key)) notification.dismiss();
//     else results.set(key, notification);
//   }
//   return Array.from(results.values()).sort((a, b) => b.get_time() - a.get_time());
// });
// export const dontDisturb = createBinding(notifd, 'dont_disturb');

export interface SwayncStatus {
  /** Number of notifications. */
  count: number;
  /** Whether Do Not Disturb is enabled. */
  dnd: boolean;
  /** Whether the notification panel is visible. */
  visible: boolean;
  /** Whether notifications are inhibited, i.e. prevented from being displayed. */
  inhibited: boolean;
}

export const swayncStatus = createSubprocess('', 'zsh -c "swaync-client -s"').as((stdout) => {
  const {
    count = 0,
    dnd = false,
    visible = false,
    inhibited = false,
  } = safeJSONParse<SwayncStatus>(stdout) ?? {};
  return { count, dnd, visible, inhibited };
});

export function setDontDisturb(value: boolean) {
  // notifd.set_dont_disturb(value);
  execAsync(`swaync-client ${value ? '-dn' : '-df'}`);
}

export function clearNotifications() {
  // for (const notification of notifd.get_notifications()) notification.dismiss();
  execAsync('swaync-client -C').catch((err) => console.error('Failed to clear notifications', err));
}

export interface NotifyOptions<ActionKey extends string> {
  /** The summary/title of the notification. */
  summary: string;
  /** The body/message of the notification. */
  body?: string;
  icon?: NativeIcon | ({} & string);
  actions?: Record<ActionKey, string>;
  expire?: number;
  urgency?: 'low' | 'normal' | 'critical';
  transient?: boolean;
  appName?: string;
  categories?: string[];
}

export async function notify<ActionKey extends string>(
  {
    summary,
    body,
    icon,
    actions,
    expire,
    urgency = 'normal',
    transient,
    appName,
    categories,
  }: NotifyOptions<ActionKey> = { summary: 'Unknown' },
): Promise<{ id: string; action?: ActionKey }> {
  const cmd = [
    'notify-send',
    summary,
    ...(body ? [body] : []),
    '--urgency',
    urgency,
    '--print-id',
    ...(categories ? ['--category', categories.join(',')] : []),
    ...(expire ? ['--expire-time', expire.toString()] : []),
    ...(appName ? ['--app-name', appName] : []),
    ...(transient ? ['--transient'] : []),
    ...(icon ? ['--icon', icon] : []),
    ...(actions
      ? Object.entries(actions).flatMap(([key, text]) => ['--action', `${key}=${text}`])
      : []),
  ].filter(Boolean);
  // console.debug('notify', cmd);
  return execAsync(cmd)
    .then((stdout) => {
      const [id, action] = stdout.split('\n');
      if (!id) raise('notification id not found');
      return { id, action: action as ActionKey | undefined };
    })
    .catch((error) => raise(new Error('Failed to send notification', { cause: error })));
}
