import { exec } from 'ags/process';
import { HOME } from './env';

const THEME_PATH = `${HOME}/.themes/adw-gtk3/gtk-4.0/gtk.css`;
const RENAME_MAP: Record<string, string> = {
  window_fg_color: 'fgColor',
  window_bg_color: 'bgColor',
};

export interface Theme {
  fgColor: string;
  bgColor: string;
  [key: string]: string | undefined;
}

export const Theme: Theme = {
  fgColor: '',
  bgColor: '',
};
for (const [match] of exec(`cat ${THEME_PATH}`).matchAll(/@define-color.+;/g)) {
  const [name, color] = match.replace('@define-color', '').replace(';', '').trim().split(' ');
  if (!color || !name) continue;
  Theme[RENAME_MAP[name] ?? name] = color;
}

