import { Gdk, Gtk } from 'ags/gtk4';
import { noop } from '../utils/fn';
import { Accessor } from 'ags';

export interface SearchInputProps {
  value?: string | Accessor<string>;
  onChange?: (value: string) => void;
  widthRequest?: number;
  onKeyPressed?: (keyval: number) => void;
  $?: (self: Gtk.SearchEntry) => void;
}

// Gtk.SearchBar has annoying side-effect where pressing escape would hide the search input.
// export default function SearchInput({ widthRequest }: SearchInputProps) {
//   return (
//     <Gtk.SearchBar searchModeEnabled widthRequest={widthRequest}>
//       <Gtk.SearchEntry editable searchDelay={300} />
//     </Gtk.SearchBar>
//   );
// }

export default function SearchInput({
  value,
  onChange = noop,
  widthRequest,
  onKeyPressed = noop,
  $ = noop,
}: SearchInputProps) {
  let input: Gtk.SearchEntry;
  return (
    <Gtk.SearchEntry
      $={(self) => {
        input = self;
        $(self);
      }}
      text={value}
      onNotifyText={(self) => {
        onChange(self.text);
      }}
      widthRequest={widthRequest}
      onNotifyVisible={(self) => {
        console.log('notify visible', self.visible);
      }}
      editable
      searchDelay={300}
    >
      <Gtk.EventControllerKey
        onKeyPressed={(_, keyval: number) => {
          if (keyval === Gdk.KEY_Escape) {
            input.set_text('');
          }
          onKeyPressed(keyval);
        }}
      />
    </Gtk.SearchEntry>
  );
}
