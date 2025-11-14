import Apps from 'gi://AstalApps';
import Icon from '../components/Icon';
import Modal from '../components/Modal';
import { Accessor, createBinding, createComputed, createState, For } from 'ags';
import { Gdk, Gtk } from 'ags/gtk4';
import { hideWindow, toggleWindow } from '../utils/window';
import { classes } from '../utils/styles';
import SearchInput from '@/components/SearchInput';
import { Hr } from '@/components/Separators';
import { iter } from 'iteragain';
import Pango from 'gi://Pango';

export const apps = new Apps.Apps({
  nameMultiplier: 2,
  entryMultiplier: 0,
  executableMultiplier: 2,
  showHidden: true,
});

export const appList = new Accessor(() =>
  apps.get_list().sort((a, b) => a.get_name().localeCompare(b.get_name())),
);

export interface AppsModalProps {
  width?: number;
  height?: number;
  gap?: number;
}

export default function AppsModal({ width = 400, height = 500, gap = 30 }: AppsModalProps) {
  let searchInput: Gtk.SearchEntry;
  const [search, setSearch] = createState('');
  const appListFiltered = createComputed([appList, search], (appList, search) =>
    iter(appList)
      .filter((app) => app.get_name().toLowerCase().includes(search.toLowerCase()))
      .chunks(5),
  );

  return (
    <Modal
      onShow={() => searchInput.grab_focus()}
      name="apps"
      width={width}
      height={height}
      cssClasses={classes('bg-transparent')}
    >
      <centerbox
        cssClasses={classes('bg-bg-color', 'rounded', 'p')}
        orientation={Gtk.Orientation.VERTICAL}
      >
        <box $type="start" cssClasses={classes()} orientation={Gtk.Orientation.VERTICAL}>
          <SearchInput
            $={(self) => (searchInput = self)}
            hexpand
            value={search}
            placeholder="Search for an app"
            onChange={setSearch}
            onKeyPressed={(keyval) => {
              if (keyval === Gdk.KEY_Escape && !search.get().length) hideWindow('apps');
            }}
          />

          <Hr marginTop={4} marginBottom={4} />
        </box>

        <scrolledwindow
          $type="center"
          hscrollbarPolicy={Gtk.PolicyType.NEVER}
          cssClasses={classes('py')}
        >
          <box
            vexpand
            hexpand={false}
            orientation={Gtk.Orientation.VERTICAL}
            spacing={gap}
            valign={Gtk.Align.CENTER}
          >
            <For each={appListFiltered}>
              {(apps) => (
                <box
                  spacing={gap}
                  orientation={Gtk.Orientation.HORIZONTAL}
                  halign={Gtk.Align.CENTER}
                >
                  {apps.map((app) => {
                    const description = createBinding(app, 'description');
                    const name = createBinding(app, 'name');
                    return (
                      <button
                        onClicked={() => {
                          app.launch();
                          hideWindow('apps');
                        }}
                        cssClasses={classes('btn-ghost')}
                      >
                        <box
                          spacing={8}
                          orientation={Gtk.Orientation.VERTICAL}
                          tooltipText={createComputed([description, name], (description, name) =>
                            [name, description].filter(Boolean).join('\n'),
                          )}
                        >
                          <image iconName={createBinding(app, 'icon_name')} pixelSize={130} />
                          <label lines={2} label={name} ellipsize={Pango.EllipsizeMode.END} />
                        </box>
                      </button>
                    );
                  })}
                </box>
              )}
            </For>
          </box>
        </scrolledwindow>

        <box $type="end">
          <label label={appList((l) => `${l.length} apps`)} />
        </box>
      </centerbox>
    </Modal>
  );
}

export function AppsButton() {
  return (
    <button onClicked={() => toggleWindow('apps')} cssClasses={classes('rounded-full')}>
      <Icon name="list" />
    </button>
  );
}
