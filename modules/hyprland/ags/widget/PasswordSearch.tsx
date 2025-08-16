import { Gtk } from 'ags/gtk4';
import { PopupWindow } from '../components/PopupWindow';
import { toggleWindow, WINDOW_NAME } from '../utils/window';
import Icon from '../components/Icon';
import SearchInput from '../components/SearchInput';

const WIDTH = 300;
const HEIGHT = 300;

export default function PasswordSearch() {
  return (
    <PopupWindow name={WINDOW_NAME.PasswordSearch} class="PasswordSearch">
      <centerbox
        class="container"
        halign={Gtk.Align.CENTER}
        valign={Gtk.Align.CENTER}
        orientation={Gtk.Orientation.VERTICAL}
        widthRequest={WIDTH}
        heightRequest={HEIGHT}
      >
        <box $type="start" halign={Gtk.Align.CENTER}>
          <SearchInput widthRequest={WIDTH} />
        </box>

        <box
          $type="center"
          halign={Gtk.Align.CENTER}
          valign={Gtk.Align.CENTER}
        >
          <label label="Hello" />
        </box>
      </centerbox>
    </PopupWindow>
  );
}

export function PasswordSearchButton() {
  return (
    <button onClicked={() => toggleWindow('password-search')}>
      <Icon name="search" />
    </button>
  );
}
