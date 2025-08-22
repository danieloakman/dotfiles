import { writeFileAsync } from 'ags/file';
import { execAsync } from 'ags/process';
import { StyleClass } from '../types/style-classes';

export async function loadStyles() {
  const text = await execAsync('cat ./style.scss');
  const classes = text.match(/^\.([a-zA-Z0-9-_]+)/gm);
  await writeFileAsync(
    './types/style-classes.ts',
    `
export const STYLE_CLASSES = ${JSON.stringify(
      classes?.map((m) => m.replace('.', '')),
      null,
      2,
    )} as const;

export type StyleClass = (typeof STYLE_CLASSES)[number];
`.trim(),
  );
}

/** Provides type safe class names as referenced in style.scss. */
export const classes = (...classes: StyleClass[]): string[] => classes;
