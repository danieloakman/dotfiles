import { createComputed, createConnection, For } from 'ags';
import Hyprland from 'gi://AstalHyprland';

const hyprland = Hyprland.get_default();

const getWorkspaces = () => hyprland.get_workspaces().filter((w) => !w.name.includes('special'));
const workspaces = createConnection(
  getWorkspaces(),
  [hyprland, 'notify::workspaces', getWorkspaces],
  [hyprland, 'workspace-added', getWorkspaces],
  [hyprland, 'workspace-removed', getWorkspaces],
);
const getFocusedWorkspace = () => hyprland.get_focused_workspace().id;
const focusedWorkspace = createConnection(
  getFocusedWorkspace(),
  [hyprland, 'notify::focused-workspace', getFocusedWorkspace],
);
const dataView = createComputed([workspaces, focusedWorkspace], (ws, f) =>
  ws
    .map((w) => ({
      workspace: w,
      selected: w.id === f,
    }))
    .sort(({ workspace: a }, { workspace: b }) => a.id - b.id),
);

export default function Workspaces() {
  return (
    <box class="workspaces">
      <For each={dataView}>
        {({ workspace, selected }) => {
          return (
            <button class={selected ? 'selected' : ''} onClicked={() => workspace.focus()}>
              <label label={workspace.name.toString()} />
            </button>
          );
        }}
      </For>
    </box>
  );
}
