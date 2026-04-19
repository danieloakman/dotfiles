import { Gdk, Gtk } from 'ags/gtk4';
import { noop } from '@/js-utils';
import { Accessor } from 'ags';

export interface SearchInputProps {
  value?: string | Accessor<string>;
  widthRequest?: number;
  hexpand?: boolean;
  placeholder?: string;
  onChange?: (value: string) => void;
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
  widthRequest,
  hexpand = false,
  placeholder = '',
  onChange = noop,
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
      placeholderText={placeholder}
      onNotifyText={(self) => onChange(self.text)}
      widthRequest={widthRequest}
      hexpand={hexpand}
      focusable
      canFocus
      editable
      searchDelay={300}
    >
      <Gtk.EventControllerKey
        onKeyPressed={(_, keyval: number) => {
          onKeyPressed(keyval);
          if (keyval === Gdk.KEY_Escape) input.set_text('');
        }}
      />
    </Gtk.SearchEntry>
  );
}
