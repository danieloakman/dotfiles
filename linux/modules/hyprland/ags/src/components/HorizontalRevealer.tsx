import { createBooleanState } from '@/utils/ags';
import { Accessor, Node } from 'ags';
import { Gtk } from 'ags/gtk4';
import Icon from './Icon';

export interface HorizontalRevealerProps {
  children?: Node | Node[];
  spacing?: number;
  initialRevealed?: boolean;
  visible?: boolean | Accessor<boolean>;
}

export default function HorizontalRevealer({
  children,
  spacing = 4,
  initialRevealed = false,
  visible,
}: HorizontalRevealerProps) {
  const [revealed, { toggle: toggleRevealed }] = createBooleanState(initialRevealed);

  return (
    <box name="HorizontalRevealer" spacing={spacing} visible={visible}>
      <button onClicked={toggleRevealed}>
        <Icon name={revealed((v) => (v ? 'chevron-right' : 'chevron-left'))} />
      </button>

      <revealer revealChild={revealed} transitionType={Gtk.RevealerTransitionType.SLIDE_RIGHT}>
        <box spacing={spacing}>{children}</box>
      </revealer>
    </box>
  );
}
