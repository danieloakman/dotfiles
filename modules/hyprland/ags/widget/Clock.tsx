import { Gtk } from 'ags/gtk4';
import { createPoll } from 'ags/time';
import { apps } from './Apps';
import { classes } from '../utils/styles';

const DATE_CMD = `date +'%I:%M:%S %b %d'`;
export const time = createPoll('', 1000, DATE_CMD);

const calendarApps = apps.fuzzy_query('calendar');

export default function Clock() {
  return (
    // The circular class is specific to the Gtk.MenuButton widget and requests a rounded border.
    <menubutton name="clock" cssClasses={['circular']}>
      <label cssClasses={classes('px-sm')} label={time} />

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
