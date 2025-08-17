import { Gtk } from 'ags/gtk4';
import { PopupWindow } from '../components/PopupWindow';
import { toggleWindow, WINDOW_NAME } from '../utils/window';
import Icon from '../components/Icon';
import SearchInput from '../components/SearchInput';
import { createComputed, createState, For } from 'ags';
import { PASSWORD_STORE_DIR } from '../utils/env';
import { createPoll } from 'ags/time';

const WIDTH = 300;
const HEIGHT = 300;

export const passwords = createPoll('', 60000, `ls ${PASSWORD_STORE_DIR}/**/*.gpg`).as((stdout) => {
  console.log(stdout);
  return stdout.split('\n').filter(Boolean);
});

export default function PasswordSearch() {
  let scrolledwindow: Gtk.ScrolledWindow;
  const [search, setSearch] = createState('');
  const passwordsFiltered = createComputed([search, passwords], (search, passwords) => {
    return passwords.filter((password) => password.includes(search));
  });
  // const [results, setResults] = createState<string[]>([]);
  // search.subscribe(() => {
  //   execAsync(`ls ${PASSWORD_STORE_DIR}`);
  // });

  return (
    <PopupWindow name={WINDOW_NAME.PasswordSearch} class="PasswordSearch">
      <centerbox
        class="container"
        halign={Gtk.Align.CENTER}
        valign={Gtk.Align.CENTER}
        orientation={Gtk.Orientation.VERTICAL}
        widthRequest={WIDTH}
        heightRequest={HEIGHT}
      >
        <box $type="start" halign={Gtk.Align.CENTER}>
          <SearchInput widthRequest={WIDTH} value={search} onChange={setSearch} />
        </box>

        <scrolledwindow $type="center" $={self => (scrolledwindow = self)}>
          <box spacing={4} vexpand orientation={Gtk.Orientation.VERTICAL}>
            <For each={passwordsFiltered}>
              {(password) => <label label={password} />}
            </For>
          </box>
        </scrolledwindow>
        {/* <box $type="center" halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}>
          
        </box> */}
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
