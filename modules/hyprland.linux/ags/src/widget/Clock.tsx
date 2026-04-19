import { Gtk } from 'ags/gtk4';
import { createPoll } from 'ags/time';
import { apps } from './Apps';
import { classes } from '../utils/styles';
import { createBinding } from 'ags';

const DATE_CMD = `date +'%I:%M:%S %b %d'`;
export const time = createPoll('', 1000, DATE_CMD);

const calendarApps = apps.fuzzy_query('calendar');

export default function Clock() {
  return (
    // The circular class is specific to the Gtk.MenuButton widget and requests a rounded border.
    <menubutton name="clock" cssClasses={classes('circular')}>
      <label cssClasses={classes('px')} label={time} />

      <popover>
        <box orientation={Gtk.Orientation.VERTICAL} spacing={4}>
          {calendarApps.map((app) => (
            <button onClicked={() => app.launch()} cssClasses={classes('btn-ghost')}>
              <box spacing={4}>
                <image iconName={createBinding(app, 'icon_name')} />
                <label label={createBinding(app, 'name')} />
              </box>
            </button>
          ))}

          <Gtk.Calendar />
        </box>
      </popover>
    </menubutton>
  );
}
