import Apps from 'gi://AstalApps';
import Icon from '../components/Icon';
import { Accessor, createComputed, createState, For } from 'ags';
import { createExternalState } from '../utils/ags';
import { Gtk } from 'ags/gtk4';

const apps = new Apps.Apps({
  nameMultiplier: 2,
  entryMultiplier: 0,
  executableMultiplier: 2,
  showHidden: true,
});

const appList = new Accessor(() => apps.get_list());

export default function AppsWidget() {
  return (
    <menubutton name="apps">
      <Icon name="power" />

      <popover
        $={(self) => {
          self.connect('notify::visible', () => {
            console.log('visible', self.get_visible());
          });
        }}
        heightRequest={500}
        hexpand
      >
        <scrolledwindow
          maxContentHeight={500}
          // vscrollbarPolicy={Gtk.PolicyType.ALWAYS}
          hscrollbarPolicy={Gtk.PolicyType.NEVER}
        >
          <label label="Apps" />
          <For each={appList}>{(app) => <button heightRequest={50} label={app.get_name()} />}</For>
        </scrolledwindow>
      </popover>
    </menubutton>
  );
}
