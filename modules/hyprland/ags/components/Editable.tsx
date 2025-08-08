import { Accessor, createConnection } from 'ags';
import { Gtk } from 'ags/gtk4';

export declare namespace Editable {
  export interface Props {
    editing?: boolean;
    value?: string | Accessor<string>;
    onChange?: (value: string) => void;
  }
}

// Fill this out out more if it's every needed.
export default function Editable({ editing = false, value = '', onChange }: Editable.Props) {
  return (
    <Gtk.EditableLabel
      $={(self) => {
        self.connect('notify::text', (p, ...args) => {
          console.log(p, args);
        });
      }}
      text={value}
      editable
      editing={editing}
    />
  );
}
