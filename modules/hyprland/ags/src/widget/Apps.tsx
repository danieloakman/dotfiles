import Apps from 'gi://AstalApps';
import Icon from '../components/Icon';
import Modal from '../components/Modal';
import { Accessor, createBinding, For } from 'ags';
import { Gtk } from 'ags/gtk4';
import { hideWindow, toggleWindow } from '../utils/window';
import { classes } from '../utils/styles';

export const apps = new Apps.Apps({
  nameMultiplier: 2,
  entryMultiplier: 0,
  executableMultiplier: 2,
  showHidden: true,
});

export const appList = new Accessor(() =>
  apps.get_list().sort((a, b) => a.get_name().localeCompare(b.get_name())),
);

export default function AppsModal() {
  return (
    <Modal name="apps" width={400} height={500} cssClasses={classes('bg-transparent')}>
      <centerbox
        cssClasses={classes('bg-bg-color', 'rounded', 'p')}
        orientation={Gtk.Orientation.VERTICAL}
      >
        <label $type="start" label="Apps" />

        <scrolledwindow
          $type="center"
          hscrollbarPolicy={Gtk.PolicyType.NEVER}
          cssClasses={classes('py')}
        >
          <box vexpand hexpand={false} orientation={Gtk.Orientation.VERTICAL} spacing={4}>
            <For each={appList}>
              {(app) => (
                <button
                  onClicked={() => {
                    app.launch();
                    hideWindow('apps');
                  }}
                >
                  <box spacing={4}>
                    <image iconName={createBinding(app, 'icon_name')} />
                    <label label={createBinding(app, 'name')} />
                  </box>
                </button>
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
