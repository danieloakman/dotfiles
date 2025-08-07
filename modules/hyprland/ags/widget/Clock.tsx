import { Gtk } from 'ags/gtk4';
import { createPoll } from 'ags/time';

// const dateCmd = `date +'%Y-%m-%d %I:%M:%S %p'`;
const dateCmd = `date +'%I:%M:%S %p'`;

export default function Clock() {
  // const [isShown, setIsShown] = createState(false);
  const time = createPoll('', 1000, dateCmd);
  // const label = createComputed([time, isShown], (t, isShown) => (isShown ? t : t.split(' ').slice(1).join(' ')));

  return (
    <menubutton name='clock'>
      <label label={time} />
      <popover>
        <Gtk.Calendar />
      </popover>
    </menubutton>
  );
}
