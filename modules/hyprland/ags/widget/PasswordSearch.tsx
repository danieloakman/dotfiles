import { Gdk, Gtk } from 'ags/gtk4';
import { PopupWindow } from '../components/PopupWindow';
import { toggleWindow, WINDOW_NAME, hideWindow } from '../utils/window';
import Icon from '../components/Icon';
import SearchInput from '../components/SearchInput';
import { createComputed, createState, For } from 'ags';
import { PASSWORD_STORE_DIR } from '../utils/env';
import { createPoll } from 'ags/time';
import { execAsync } from 'ags/process';

const WIDTH = 300;
const HEIGHT = 300;

const cleanRe = /^\/|\.gpg$/g;

export const passwords = createPoll('', 60000, `zsh -c "ls ${PASSWORD_STORE_DIR}/**/*.gpg"`).as(
  (stdout) =>
    stdout
      .split('\n')
      .filter(Boolean)
      .map((path) => path.replace(PASSWORD_STORE_DIR, '').replace(cleanRe, '')),
);

const overflowToNewline = (text: string, maxLength: number): string => {
  if (text.length <= maxLength) return text;
  if (text.includes('/')) {
    const parts = text.split('/');
    return parts[0] + '/\n' + overflowToNewline(parts.slice(1).join('/'), maxLength);
  }
  return (
    text.slice(0, maxLength - 3) + '\n' + overflowToNewline(text.slice(maxLength - 3), maxLength)
  );
};

const fuzzySearch = (query: string, entries: string[]): string[] => {
  const queryWords = query.split(' ').filter(Boolean);
  return entries.filter((entry) => {
    const entryWords = entry.split(' ').filter(Boolean);
    return queryWords.every((word) => entryWords.some((e) => e.includes(word)));
  });
};

export default function PasswordSearch() {
  let scrolledwindow: Gtk.ScrolledWindow;
  let searchInput: Gtk.SearchEntry;
  const [search, setSearch] = createState('');
  const passwordsFiltered = createComputed([search, passwords], (search, passwords) =>
    fuzzySearch(search, passwords),
  );

  return (
    <PopupWindow
      name={WINDOW_NAME.PasswordSearch}
      class="PasswordSearch"
      onShow={() => searchInput.grab_focus()}
    >
      <centerbox
        class="container"
        orientation={Gtk.Orientation.VERTICAL}
        widthRequest={WIDTH}
        heightRequest={HEIGHT}
      >
        <box $type="start">
          <SearchInput
            $={(self) => (searchInput = self)}
            hexpand
            value={search}
            onChange={setSearch}
            onKeyPressed={(keyval) => {
              if (keyval === Gdk.KEY_Escape && !search.get().length)
                hideWindow(WINDOW_NAME.PasswordSearch);
            }}
          />
        </box>

        <scrolledwindow
          $type="center"
          $={(self) => (scrolledwindow = self)}
          hscrollbarPolicy={Gtk.PolicyType.NEVER}
        >
          <box
            spacing={4}
            vexpand
            hexpand={false}
            orientation={Gtk.Orientation.VERTICAL}
            valign={Gtk.Align.START}
          >
            <For each={passwordsFiltered}>
              {(password) => (
                <button
                  class="password-button"
                  onClicked={() => {
                    if (password.startsWith('otp/')) execAsync(`pass otp ${password} -c`);
                    else execAsync(`pass ${password} -c`);
                    hideWindow(WINDOW_NAME.PasswordSearch);
                    setSearch('');
                  }}
                >
                  <label label={overflowToNewline(password, 30)} halign={Gtk.Align.START} />
                </button>
              )}
            </For>
          </box>
        </scrolledwindow>

        <box $type="end">
          <label label={passwordsFiltered.as((passwords) => `${passwords.length} results`)} />
        </box>
      </centerbox>
    </PopupWindow>
  );
}

export function PasswordSearchButton() {
  return (
    <button onClicked={() => toggleWindow('password-search')}>
      <Icon name="search" />
    </button>
  );
}
