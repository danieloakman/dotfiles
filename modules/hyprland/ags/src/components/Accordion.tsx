import { Node, With } from 'ags';
import { Gtk } from 'ags/gtk4';
import Icon from './Icon';
import { noop } from '@/js-utils';
import { Accessor } from 'ags';
import { toAccessor } from '../utils/ags';

export interface AccordionProps {
  title: () => Node;
  children: Node;
  cssClasses?: string[];
  css?: string;
  open?: boolean | Accessor<boolean>;
  onOpenChange?: (open: boolean) => void;
}

export default function Accordion({
  title,
  children,
  cssClasses = [],
  css,
  open = false,
  onOpenChange = noop,
}: AccordionProps) {
  const _open = toAccessor(open);

  return (
    <centerbox orientation={Gtk.Orientation.VERTICAL} cssClasses={cssClasses} css={css}>
      <button $type="start" onClicked={() => onOpenChange(!_open.get())}>
        <centerbox>
          <box $type="start">{title()}</box>
          <Icon $type="end" name={_open((v) => (v ? 'chevron-down' : 'chevron-right'))} />
        </centerbox>
      </button>

      <revealer $type="center" revealChild={_open}>
        {children}
      </revealer>
    </centerbox>
  );
}
