import { NativeIcon } from '@/types/icons';
import { createState } from 'ags';
import { execAsync } from 'ags/process';
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

export function setDontDisturb(value: boolean) {
  // notifd.set_dont_disturb(value);
}

export function clearNotifications() {
  // for (const notification of notifd.get_notifications()) notification.dismiss();
}

export interface NotifyOptions<ActionKey extends string> {
  icon?: NativeIcon;
  actions?: Record<ActionKey, string>;
  expire?: number;
  urgency?: 'low' | 'normal' | 'critical';
}

export async function notify<ActionKey extends string>(
  message: string,
  { icon, actions, expire = 5000, urgency = 'normal' }: NotifyOptions<ActionKey> = {},
) {
  return execAsync(
    [
      'notify-send',
      message,
      '-t',
      expire.toString(),
      '-u',
      urgency,
      ...(icon ? ['-i', icon] : []),
      ...(actions ? Object.entries(actions).map(([key, text]) => `-A "${key}=${text}"`) : []),
    ].filter(Boolean),
  )
    .then((stdout) => {
      if (actions) return stdout;
    })
    .catch((error) => {
      console.error('Failed to send notification', error);
    });
}
