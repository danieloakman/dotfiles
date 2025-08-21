import Apps from 'gi://AstalApps';
import Icon from '../components/Icon';
import Modal from '../components/Modal';
import { Accessor, For } from 'ags';
import { Gtk } from 'ags/gtk4';
import { hideWindow, toggleWindow } from '../utils/window';

const apps = new Apps.Apps({
  nameMultiplier: 2,
  entryMultiplier: 0,
  executableMultiplier: 2,
  showHidden: true,
});

const appList = new Accessor(() => apps.get_list());

export default function AppsModal() {
  return (
    <Modal name="apps" width={400} height={500} cssClasses={['bg-transparent']}>
      <centerbox
        cssClasses={['bg-bg-color', 'rounded-sm', 'p-sm']}
        orientation={Gtk.Orientation.VERTICAL}
      >
        <label $type="start" label="Apps" cssClasses={[]} />

        <scrolledwindow
          $type="center"
          hscrollbarPolicy={Gtk.PolicyType.NEVER}
          cssClasses={['py-sm']}
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
                    <image iconName={app.get_icon_name()} />
                    <label label={app.get_name()} />
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
    <button onClicked={() => toggleWindow('apps')}>
      <Icon name="list" />
    </button>
  );
}
