import { StyleClass } from '@/types/style-classes';
import { toAccessor } from '@/utils/ags';
import { classes } from '@/utils/styles';
import { Accessor } from 'ags';

export type CardProps = Omit<JSX.IntrinsicElements['box'], 'cssClasses'> & {
  cssClasses?: StyleClass[] | Accessor<StyleClass[]>;
};

export default function Card({ cssClasses = [], children, spacing = 4, ...props }: CardProps) {
  const _cssClasses = toAccessor(cssClasses);
  return (
    <box {...props} spacing={spacing} cssClasses={_cssClasses.as((c) => classes('border', 'p-sm', 'rounded', ...c))}>
      {children}
    </box>
  );
}
