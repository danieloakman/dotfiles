import { writeFileAsync } from 'ags/file';
import { Gtk } from 'ags/gtk4';
import { NATIVE_ICONS, NativeIcon } from '../types/icons';
import { Accessor } from 'ags';
import { DEV } from '@/utils/env';

export type { NativeIcon };

/** Generates the `types/icons.ts` file */
export function NativeIconProvider() {
  return (
    <Gtk.IconTheme
      $={async (self) => {
        await writeFileAsync(
          './src/types/icons.ts',
          `
export const NATIVE_ICONS = ${JSON.stringify(self.get_icon_names().sort(), null, 2)} as const;

export type NativeIcon = (typeof NATIVE_ICONS)[number];
`.trim(),
        ).catch((err) => {
          if (!DEV) return;
          console.error('Failed to load icons', err);
        });
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

export function lookupNativeIcon(name: string): NativeIcon | undefined {
  if (NATIVE_ICONS.includes(name as NativeIcon)) return name as NativeIcon;
  return NATIVE_ICONS.find(
    (i) =>
      i.toLowerCase().includes(name.toLowerCase()) || name.toLowerCase().includes(i.toLowerCase()),
  );
}
