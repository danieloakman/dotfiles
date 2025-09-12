import { Accessor, createBinding, createComputed, For, With } from 'ags';
import { classes } from '../utils/styles';
import { workspaces, focusedWorkspace, focusedClient } from '../utils/hyprland';
import NativeIcon, {
  lookupNativeIcon,
  NativeIcon as NativeIconType,
} from '@/components/NativeIcon';
import { Gtk } from 'ags/gtk4';

export default function Workspaces() {
  const dataView = createComputed([workspaces, focusedWorkspace], (ws, f) =>
    ws
      .map((w) => ({
        workspace: w,
        selected: w.get_id() === f.get_id(),
      }))
      .sort(({ workspace: a }, { workspace: b }) => a.get_id() - b.get_id()),
  );
  return (
    <box cssClasses={classes('rounded-full', 'bg-selected', 'color-fg-color')}>
      <For each={dataView}>
        {({ workspace, selected }) => {
          const clients = createBinding(workspace, 'clients');
          const name = createBinding(workspace, 'name');
          return (
            <button
              cssClasses={classes(
                'rounded-full',
                // @ts-ignore Ignore for now
                ...(selected ? ['bg-fg-color', 'color-bg-color'] : ['bg-transparent']),
              )}
              onClicked={() => workspace.focus()}
            >
              <box spacing={4} halign={Gtk.Align.CENTER}>
                <label label={name} />
                <For
                  each={
                    clients.as((arr) =>
                      Array.from(
                        new Set(arr.map((c) => lookupNativeIcon(c.get_class())).filter(Boolean)),
                      ),
                    ) as Accessor<NativeIconType[]>
                  }
                >
                  {(c) => <NativeIcon name={c} />}
                </For>
              </box>
            </button>
          );
        }}
      </For>
    </box>
  );
}

export function FocusedClient() {
  return (
    <box name="focused-client">
      <With value={focusedClient}>
        {(client) => {
          return client && <label label={client.get_title()} />;
        }}
      </With>
    </box>
  );
}
