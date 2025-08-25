import { createBinding, createComputed, For, With } from 'ags';
import Hyprland from 'gi://AstalHyprland';
import { classes } from '../utils/styles';

const hyprland = Hyprland.get_default();

export const workspaces = createBinding(hyprland, 'workspaces').as((ws) =>
  ws.filter((w) => !w.name.includes('special')),
);
export const focusedWorkspace = createBinding(hyprland, 'focusedWorkspace');
export const focusedClient = createBinding(hyprland, 'focusedClient');

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
          return (
            <button
              cssClasses={classes(
                'rounded-full',
                // @ts-ignore Ignore for now
                ...(selected ? ['bg-fg-color', 'color-bg-color'] : ['bg-transparent']),
              )}
              onClicked={() => workspace.focus()}
            >
              <label label={workspace.name.toString()} />
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
