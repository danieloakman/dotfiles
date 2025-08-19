import { Accessor, createComputed } from 'ags';
import { Gtk } from 'ags/gtk4';
import { toAccessor } from '../utils/ags';

export interface DropDownSelectProps<T extends string> {
  options: readonly T[] | Accessor<readonly T[]>;
  selected: T | Accessor<T>;
  onSelected: (selected: T) => void;
}

export default function DropDownSelect<T extends string>({
  options,
  selected,
  onSelected,
}: DropDownSelectProps<T>) {
  const optionsAccessor = toAccessor(options);
  const selectedAccessor = toAccessor(selected);
  return (
    <Gtk.DropDown
      selected={createComputed([optionsAccessor, selectedAccessor], (options, selected) =>
        options.indexOf(selected),
      )}
      model={optionsAccessor((o) => Gtk.StringList.new(o as unknown as string[]))}
      onNotifySelectedItem={(s) => {
        const newSelected = optionsAccessor.get()[s.get_selected()];
        if (!newSelected) throw new Error('Selected item is undefined');
        onSelected(newSelected);
      }}
    />
  );
}
