import { Gtk } from 'ags/gtk4';
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

export default function PasswordSearch() {
  let scrolledwindow: Gtk.ScrolledWindow;
  const [search, setSearch] = createState('');
  const passwordsFiltered = createComputed([search, passwords], (search, passwords) =>
    passwords.filter((password) => password.includes(search)),
  );

  return (
    <PopupWindow name={WINDOW_NAME.PasswordSearch} class="PasswordSearch">
      <centerbox
        class="container"
        orientation={Gtk.Orientation.VERTICAL}
        widthRequest={WIDTH}
        heightRequest={HEIGHT}
      >
        <box $type="start" halign={Gtk.Align.CENTER}>
          <SearchInput widthRequest={WIDTH} value={search} onChange={setSearch} />
        </box>

        <scrolledwindow
          $type="center"
          $={(self) => (scrolledwindow = self)}
          hscrollbarPolicy={Gtk.PolicyType.NEVER}
        >
          <box spacing={4} vexpand orientation={Gtk.Orientation.VERTICAL} valign={Gtk.Align.START}>
            <For each={passwordsFiltered}>
              {(password) => (
                <button
                  label={password}
                  onClicked={() => {
                    execAsync(`pass ${password} -c`);
                    hideWindow(WINDOW_NAME.PasswordSearch);
                  }}
                />
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
