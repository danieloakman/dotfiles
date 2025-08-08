import { Gtk } from 'ags/gtk4';

// Fill in more if ever needed.
export default function SearchInput() {
  return (
    <Gtk.SearchBar searchModeEnabled>
      <Gtk.SearchEntry editable searchDelay={300} />
    </Gtk.SearchBar>
  );
}
