import { Gtk } from 'ags/gtk4';

export interface SearchInputProps {
  widthRequest?: number;
}

// Fill in more if ever needed.
export default function SearchInput({ widthRequest }: SearchInputProps) {
  return (
    <Gtk.SearchBar
      searchModeEnabled
      // onNotifyVisible={(self) => {
      //   if (self.visible) {
      //     self.grab_focus();
      //   }
      // }}
      widthRequest={widthRequest}
      // onShow={(self) => {
      //   console.log('show');
      //   self.grab_focus();
      // }}
    >
      <Gtk.SearchEntry
        editable
        searchDelay={300}
        // onNotifyVisible={(self) => {
        //   if (self.visible) {
        //     self.grab_focus();
        //   }
        // }}
        // onUnrealize={(self) => {
        //   console.log('unrealize');
        //   self.realize();
        //   self.show();
        //   self.grab_focus();
        // }}
        // onHide={(self) => {
        //   console.log('hide');
        //   self.show();
        //   self.realize();
        // }}
      />
    </Gtk.SearchBar>
  );
}
