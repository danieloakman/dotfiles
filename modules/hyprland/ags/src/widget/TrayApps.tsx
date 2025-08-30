import { trayItems } from '@/utils/tray';
import { For } from 'ags';
import { Gtk } from 'ags/gtk4';

export default function TrayApps() {
  return (
    <box name="TrayApps" orientation={Gtk.Orientation.VERTICAL}>
      <For each={trayItems}>
        {(item) => (
          <box>
            <image iconName={item.iconName} />
            <label>{item.title}</label>
          </box>
        )}
      </For>
    </box>
  );
}
