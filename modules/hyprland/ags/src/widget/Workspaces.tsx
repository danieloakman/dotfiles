import { Accessor, createBinding, createComputed, For, With } from 'ags';
import { classes } from '../utils/styles';
import { workspaces, focusedWorkspace, focusedClient } from '../utils/hyprland';
import NativeIcon, {
  lookupNativeIcon,
  NativeIcon as NativeIconType,
} from '@/components/NativeIcon';

export default function Workspaces() {
  const dataView = createComputed([workspaces, focusedWorkspace], (ws, f) =>
    ws
      .map((w) => ({
        workspace: w,
        selected: w.id === f.id,
      }))
      .sort(({ workspace: a }, { workspace: b }) => a.id - b.id),
  );
  return (
    <box cssClasses={classes('rounded-full', 'bg-selected', 'color-fg-color')}>
      <For each={dataView}>
        {({ workspace, selected }) => {
          const clients = createBinding(workspace, 'clients');
          return (
            <button
              cssClasses={classes(
                'rounded-full',
                // @ts-ignore Ignore for now
                ...(selected ? ['bg-fg-color', 'color-bg-color'] : ['bg-transparent']),
              )}
              onClicked={() => workspace.focus()}
            >
              <box spacing={4}>
                <label label={workspace.name.toString()} />
                <For
                  each={
                    clients.as((arr) =>
                      Array.from(
                        new Set(arr.map((c) => lookupNativeIcon(c.class)).filter(Boolean)),
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
