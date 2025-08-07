import Glib from 'gi://GLib';

export const HOME = Glib.getenv('HOME');
/** Is true if the app is being run from the dotfiles repository directory. */
export const DEV = Glib.get_current_dir().startsWith(`${HOME}/.config`);
