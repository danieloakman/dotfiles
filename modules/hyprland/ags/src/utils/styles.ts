import { writeFileAsync } from 'ags/file';
import { execAsync } from 'ags/process';
import { StyleClass } from '../types/style-classes';
import { DEV } from './env';
import { attempt } from './fn';

export async function loadStyles() {
  const { data: text, error } = await attempt(execAsync('cat ./src/style.scss'));
  if (error) {
    if (DEV) console.error('Failed to cat style.scss', error);
    return;
  }
  const classes = text.match(/^\.([a-zA-Z0-9-_]+)/gm);
  await writeFileAsync(
    './src/types/style-classes.ts',
    `
export const STYLE_CLASSES = ${JSON.stringify(
      classes?.map((m) => m.replace('.', '')),
      null,
      2,
    )} as const;

export type StyleClass = (typeof STYLE_CLASSES)[number];
`.trim(),
  ).catch((err) => {
    if (!DEV) return;
    console.error('Failed to write style-classes.ts', err);
  });
}

/** Provides type safe class names as referenced in style.scss. */
export const classes = (...classes: (StyleClass | boolean | null | undefined | (string & {}))[]): string[] =>
  classes.filter(Boolean) as string[];
