import { sleep } from '@danoaky/js-utils/functional';
import { execAsync } from 'ags/process';

export interface ToastOptions {
  icon?: string;
}

export async function toast(message: string, { icon }: ToastOptions = {}) {
  await execAsync(
    `swayosd-client --custom-message "${message}" ${icon ? `--custom-icon ${icon}` : ''}`,
  ).catch((err) => console.error('Failed to show toast', err));
}
