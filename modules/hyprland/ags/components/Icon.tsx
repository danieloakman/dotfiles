import { Gtk } from 'ags/gtk4';
import GLib from 'gi://GLib';
import { Accessor, createComputed, createExternal, createState, onMount, With } from 'ags';
import { readFileAsync, writeFileAsync } from 'ags/file';
import { Theme } from '../utils/theme';
import { execAsync } from 'ags/process';
import { toAccessor } from '../utils/ags';

const CURRENT_DIR = GLib.get_current_dir();
const ICONS_DIR = `${CURRENT_DIR}/icons`;
const TMP_ICONS_DIR = '/tmp/ags-icons';

/** See https://lucide.dev/icons/ for more. Download and put in [PROJECT]/icons/** */
export const ICONS = [
  'cpu',
  'memory-stick',
  'bluetooth',
  'bluetooth-connected',
  'bluetooth-off',
  'bluetooth-searching',
  'wifi',
  'wifi-off',
  'wifi-zero',
  'wifi-low',
  'wifi-high',
  'volume',
  'volume-1',
  'volume-2',
  'volume-off',
  'battery-charging',
  'battery',
  'battery-low',
  'battery-medium',
  'battery-full',
  'power',
  'sun',
] as const;

async function loadIcon(name: Icon.Name, color: string) {
  const src = `${ICONS_DIR}/${name}.svg`;
  const dest = `${TMP_ICONS_DIR}/${name}-${color}.svg`;
  if (await execAsync(`cat ${dest}`).catch(() => false)) return dest;
  const icon = await readFileAsync(src).catch((err) => {
    throw new Error(`Icon ${name} not found`, { cause: err });
  });
  await writeFileAsync(dest, icon.replace('currentColor', color));
  return dest;
}

export declare namespace Icon {
  export type Name = (typeof ICONS)[number];
  export interface Props
    extends Partial<Omit<Gtk.Image.ConstructorProps, 'iconName' | 'pixelSize' | 'file' | 'name'>> {
    name: Name | Accessor<Name>;
    size?: number | Accessor<number>;
    color?: string | Accessor<string>;
  }
}

export function Icon({ name, size = 18, color = Theme.fgColor, ...props }: Icon.Props) {
  const computed = createComputed(
    [toAccessor(name), toAccessor(color)],
    (name, color) => [name, color] as const,
  );
  const iconPath = createExternal<string | undefined>(undefined, (set) => {
    // Load the icon with the first values:
    loadIcon(...computed.get()).then(set);

    // Subscribe to changes and reload the icon:
    return computed.subscribe(() => {
      loadIcon(...computed.get()).then(set);
    });
  });

  return (
    <box name={`${name}-${color}-icon-box`}>
      <With value={iconPath}>
        {(iconPath) =>
          iconPath && (
            <image name={`${name}-${color}-icon`} file={iconPath} pixelSize={size} {...props} />
          )
        }
      </With>
    </box>
  );
}
export default Icon;
