import { Accessor } from 'ags';
import { Gtk } from 'ags/gtk4';

export interface VrProps extends Partial<Gtk.Separator.ConstructorProps> {}

export function Vr(props: VrProps) {
  return <Gtk.Separator {...props} />;
}

export interface HrProps extends Omit<Partial<JSX.IntrinsicElements['box']>, 'name'> {
  width?: number;
}

export function Hr({ width = 2, css = '', ...props }: HrProps) {
  return (
    <box
      name="Hr"
      css={`
        border-bottom: ${width}px solid var(--border-color);
        ${css}
      `}
      {...props}
    ></box>
  );
}
