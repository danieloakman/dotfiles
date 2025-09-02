import { Gtk } from 'ags/gtk4';

export declare namespace Spinner {
  export interface Props extends Gtk.Spinner.ConstructorProps {}
}

export default function Spinner({
  spinning = true,
  tooltipText = 'Loading...',
  ...props
}: Spinner.Props) {
  return <Gtk.Spinner spinning={spinning} tooltipText={tooltipText} {...props} />;
}
