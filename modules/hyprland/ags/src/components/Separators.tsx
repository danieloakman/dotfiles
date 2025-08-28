import { Gtk } from 'ags/gtk4';

export interface VrProps extends Partial<Gtk.Separator.ConstructorProps> {}

export function Vr(props: VrProps) {
  return <Gtk.Separator {...props} />;
}

/** FIXME: this is just a Vr at the moment. */
export function Hr() {
  return <Gtk.Separator class="horizontal" />;
}
