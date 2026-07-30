import Glib from 'gi://GLib';

export const HOME = Glib.getenv('HOME');
/** True when running from the dotfiles checkout (under ~/.config). */
export const DEV = Glib.get_current_dir().startsWith(`${HOME}/.config`);
export const PASSWORD_STORE_DIR = Glib.getenv('PASSWORD_STORE_DIR') ?? `${HOME}/.password-store`;
export const CONFIG_DIR = `${HOME}/.config/ags-config`;
