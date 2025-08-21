import { Gtk } from 'ags/gtk4';
import { createPoll } from 'ags/time';
import { apps } from './Apps';

// const dateCmd = `date +'%Y-%m-%d %I:%M:%S %p'`;
const dateCmd = `date +'%I:%M:%S %p'`;

const calendarApps = apps.fuzzy_query('calendar');

export default function Clock() {
  const time = createPoll('', 1000, dateCmd);

  return (
    <menubutton name="clock">
      <label label={time} />
      <popover>
        <box orientation={Gtk.Orientation.VERTICAL}>
          {calendarApps.map((app) => (
            <button onClicked={() => app.launch()}>
              <box spacing={4}>
                <image iconName={app.get_icon_name()} />
                <label label={app.get_name()} />
              </box>
            </button>
          ))}
          <Gtk.Calendar />
        </box>
      </popover>
    </menubutton>
  );
}
