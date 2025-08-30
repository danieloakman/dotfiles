import { NativeIcon } from '@/types/icons';
import { createBinding } from 'ags';
import { execAsync } from 'ags/process';
import Notifd from 'gi://AstalNotifd';
const notifd = Notifd.get_default();

export const notifications = createBinding(notifd, 'notifications');

export const dontDisturb = createBinding(notifd, 'dont_disturb');

export function setDontDisturb(value: boolean) {
  notifd.set_dont_disturb(value);
}

export function notify(message: string) {
}

// export interface NotifyOptions<ActionKey extends string> {
//   icon?: NativeIcon;
//   actions?: Record<ActionKey, string>;
//   expire?: number;
//   urgency?: 'low' | 'normal' | 'critical';
// }

// export async function notify<ActionKey extends string>(
//   message: string,
//   { icon, actions, expire = 5000, urgency = 'normal' }: NotifyOptions<ActionKey> = {},
// ) {
//   return execAsync(
//     [
//       'notify-send',
//       message,
//       `-t ${expire}`,
//       `-u ${urgency}`,
//       ...(icon ? ['-i', icon] : []),
//       ...(actions ? Object.entries(actions).map(([key, text]) => `-A "${key}=${text}"`) : []),
//     ].filter(Boolean),
//   )
//     .then((stdout) => {
//       if (actions) return stdout;
//     })
//     .catch((error) => {
//       console.error('Failed to send notification', error);
//     });
// }
