import { writeFileAsync } from 'ags/file';
import { Gtk } from 'ags/gtk4';
import { NativeIcon } from '../types/icons';
import { Accessor } from 'ags';
import { noop } from '../utils/fn';

/** Generates the `types/icons.ts` file */
export function NativeIconProvider() {
  return (
    <Gtk.IconTheme
      $={async (self) => {
        await writeFileAsync(
          './types/icons.ts',
          `
export const NATIVE_ICONS = ${JSON.stringify(self.get_icon_names(), null, 2)} as const;

export type NativeIcon = (typeof NATIVE_ICONS)[number];
`.trim(),
        ).catch(noop); // Ignore errors
      }}
    />
  );
}

export interface NativeIconProps {
  name: NativeIcon | Accessor<NativeIcon>;
  size?: number;
}

export default function NativeIcon({ name, size = 18 }: NativeIconProps) {
  return <image iconName={name} pixelSize={size} />;
}
