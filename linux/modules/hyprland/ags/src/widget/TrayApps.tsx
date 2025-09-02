import { classes } from '@/utils/styles';
import { For, createBinding } from 'ags';
import { Gtk } from 'ags/gtk4';
import Tray from 'gi://AstalTray';

const tray = Tray.get_default();

export const trayItems = createBinding(tray, 'items').as((items) =>
  items.filter((item) => !item.title.includes('blue')),
);

export default function TrayApps() {
  return (
    <box name="TrayApps" visible={trayItems((v) => v.length > 0)}>
      <For each={trayItems}>
        {(item) => {
          const title = createBinding(item, 'title');
          const gicon = createBinding(item, 'gicon');
          const iconName = createBinding(item, 'iconName');
          const menuModel = createBinding(item, 'menuModel');
          return item.isMenu ? (
            <menubutton menuModel={menuModel} tooltipText={title} />
          ) : (
            <button
              onClicked={() => item.activate(0, 0)}
              cssClasses={classes('rounded-full')}
              tooltipText={item.title || item.tooltipText}
            >
              <image iconName={iconName} gicon={gicon} />
            </button>
          );
        }}
      </For>
    </box>
  );
}
