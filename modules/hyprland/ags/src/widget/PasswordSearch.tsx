import { Gdk, Gtk } from 'ags/gtk4';
import Modal from '../components/Modal';
import { toggleWindow, WINDOW_NAME, hideWindow } from '../utils/window';
import Icon from '../components/Icon';
import SearchInput from '../components/SearchInput';
import { createComputed, createState, For } from 'ags';
import { PASSWORD_STORE_DIR, CONFIG_DIR } from '../utils/env';
import { createPoll } from 'ags/time';
import { execAsync } from 'ags/process';
import { createExternalState } from '../utils/ags';
import { iife } from '../utils/fn';
import { readFileAsync, writeFileAsync } from 'ags/file';
import DropDownSelect from '../components/DropDownSelect';
import { classes } from '../utils/styles';

const WIDTH = 300;
const HEIGHT = 400;
const CLEAN_REGEX = /^\/|\.gpg$/g;
const PRIORITY_PATH = `${CONFIG_DIR}/password-search-priority.json`;
const SORT_OPTIONS = ['priority', 'alphabetical'] as const;
type SortOption = (typeof SORT_OPTIONS)[number];

export const passwords = createPoll('', 60000, `zsh -c "echo ${PASSWORD_STORE_DIR}/**/*.gpg"`).as(
  (stdout) =>
    stdout
      .split(' ')
      .filter(Boolean)
      .map((path) => path.replace(PASSWORD_STORE_DIR, '').replace(CLEAN_REGEX, '')),
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

const { priority, incrementPriority } = iife(() => {
  const [priority, setPriority] = createExternalState({} as Record<string, number>, (set) => {
    readFileAsync(PRIORITY_PATH).then((fileContent) => set(JSON.parse(fileContent)));
  });
  return {
    priority,
    incrementPriority: async (key: string) => {
      const newPriority = { ...priority.get(), [key]: Date.now() };
      setPriority(newPriority);
      await writeFileAsync(PRIORITY_PATH, JSON.stringify(newPriority));
    },
  };
});

export default function PasswordSearch() {
  let searchInput: Gtk.SearchEntry;
  const [search, setSearch] = createState('');
  const [sortBy, setSortBy] = createState<SortOption>('priority');
  const sortByFn = createComputed([sortBy, priority], (sortBy, priority) => {
    if (sortBy === 'priority')
      return (a: string, b: string) => (priority[b] ?? 0) - (priority[a] ?? 0);
    return (a: string, b: string) => a.localeCompare(b);
  });
  const passwordsFiltered = createComputed(
    [search, passwords, sortByFn],
    (search, passwords, sortByFn) => fuzzySearch(search, passwords).sort(sortByFn),
  );

  return (
    <Modal name={WINDOW_NAME.PasswordSearch} onShow={() => searchInput.grab_focus()}>
      <centerbox
        cssClasses={classes('bg-bg-color', 'p-sm', 'rounded')}
        orientation={Gtk.Orientation.VERTICAL}
        widthRequest={WIDTH}
        heightRequest={HEIGHT}
      >
        <box $type="start" cssClasses={classes()}>
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
          hscrollbarPolicy={Gtk.PolicyType.NEVER}
        >
          <box
            spacing={4}
            cssClasses={classes('py-sm')}
            vexpand
            hexpand={false}
            orientation={Gtk.Orientation.VERTICAL}
            valign={Gtk.Align.START}
          >
            <For each={passwordsFiltered}>
              {(password) => (
                <button
                  cssClasses={classes('btn-ghost')}
                  onClicked={() => {
                    if (password.startsWith('otp/')) execAsync(`pass otp ${password} -c`);
                    else execAsync(`pass ${password} -c`);
                    hideWindow(WINDOW_NAME.PasswordSearch);
                    setSearch('');
                    incrementPriority(password);
                  }}
                >
                  <label label={overflowToNewline(password, 30)} halign={Gtk.Align.START} />
                </button>
              )}
            </For>
          </box>
        </scrolledwindow>

        <centerbox $type="end">
          <box $type="start">
            <label label={passwordsFiltered.as((passwords) => `${passwords.length} results`)} />
          </box>

          <box $type="end">
            <DropDownSelect options={SORT_OPTIONS} selected={sortBy} onSelected={setSortBy} />
          </box>
        </centerbox>
      </centerbox>
    </Modal>
  );
}

export function PasswordSearchButton() {
  return (
    <button cssClasses={classes('rounded-full')} onClicked={() => toggleWindow('password-search')}>
      <Icon name="search" />
    </button>
  );
}
