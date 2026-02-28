#! bun
import { $, file, write } from 'bun';
import { constant, memoize, raise, sh } from '@danoaky/js-utils';
import { globIterateSync } from 'glob';
import { iter } from 'iteragain';
import { join, relative } from 'path';
import meow from 'meow';
import clipboard from 'clipboardy';
import { cacheDir } from './lib/env';

function exit(message: string, code = 1): never {
  console.error(message);
  process.exit(code);
}

const previousPasswordFile = file(join(cacheDir(), 'passs-previous'));
const priorityFile = file(join(cacheDir(), 'passs-priority'), { type: 'application/json' });
const priorityJson = (): Promise<Record<string, number | undefined>> => priorityFile.json().catch(constant({}));
const regularLineRe = /^[^:]+:.+$/;

async function updatePriority(password: string) {
  return priorityJson().then(async (priority) => {
    priority[password] = Date.now();
    return write(priorityFile, JSON.stringify(priority, null, 2));
  });
}

const fuzzyFindCmd = (files: string, { prompt = 'pass' }: { prompt?: string } = {}) =>
  (process.stdout.isTTY
    ? $`echo ${files} | fzf --no-multi`
    : $`echo ${files} | rofi -dmenu -p "${prompt}" -i -no-custom -matching fuzzy`
  )
    .text()
    .then((stdout) => stdout.trim());

async function getSelectedPassword(): Promise<string> {
  const priority = await priorityJson();

  const passDir = process.env.PASSWORD_STORE_DIR ?? raise('PASSWORD_STORE_DIR is not set');
  const gpgFiles = iter(globIterateSync(`${passDir}/**/*.gpg`))
    .map((file) => relative(passDir, file).replace(/\.gpg$/, ''))
    .sort((a, b) => (priority[b] ?? 0) - (priority[a] ?? 0))
    .join('\n');
  const selectedPassword = await fuzzyFindCmd(gpgFiles, { prompt: 'pass' });
  if (!selectedPassword) exit('No password selected');
  return selectedPassword;
}

async function getSelectedField(password: string): Promise<{ index: number; value: string }> {
  const contents = await showPassword(password);
  const [pwd, ...fields] = contents.trim().split('\n');
  const selection = ['*'.repeat(pwd?.length ?? 8) + ' (Password)', ...fields];
  const selectedField = await fuzzyFindCmd(selection.join('\n'), { prompt: 'field' });
  if (!selectedField) exit('No field selected');
  const index = selection.indexOf(selectedField);
  return { index, value: selectedField };
}

const showPassword = memoize(async (password: string) => $`pass show ${password}`.text());

function isFileContentsStandard(contents: string): boolean {
  const [pwd, ...fields] = contents.trim().split('\n');
  return (pwd?.length ?? 0) > 0 && iter(fields).every((line) => regularLineRe.test(line));
}

async function main() {
  const cli = meow(
    `
    -- Password search & select --

    Usage:
    $ passs [Options]

    Options:
    --help, -h    Show help
    --copy, -c    Copy the password to clipboard
  `,
    {
      importMeta: import.meta,
      flags: {
        help: {
          type: 'boolean',
          shortFlag: 'h',
        },
        copy: {
          type: 'boolean',
          shortFlag: 'c',
        },
      },
    }
  );

  if (cli.flags.help) {
    console.log(cli.help);
    return;
  }

  const selectedPassword = await getSelectedPassword().then(async (result) => {
    await write(previousPasswordFile, result);
    return result;
  });

  await updatePriority(selectedPassword);

  // TODO: fix wayland bug where copy flag makes the program hang
  if (selectedPassword.startsWith('otp')) {
    await sh(`pass otp ${selectedPassword}${cli.flags.copy ? ' -c' : ''}`);
  } else if (!cli.flags.copy) {
    await sh(`pass ${selectedPassword}`);
  } else if (!isFileContentsStandard(await showPassword(selectedPassword))) {
    const pwdContents = await showPassword(selectedPassword);
    if (cli.flags.copy) await clipboard.write(pwdContents);
    else console.log(pwdContents);
  } else {
    const { index, value } = await getSelectedField(selectedPassword);
    if (index === 0) await sh(`pass ${selectedPassword} -c`);
    else {
      if (value.includes(':')) {
        // eslint-disable-next-line @typescript-eslint/no-unused-vars
        const [_key, field] = value.split(':');
        if (!field) exit(`Nothing to copy from "${value}"`);
        await clipboard.write(field.trim());
        console.log(`Copied ${field.trim()} to clipboard.`);
      } else {
        await clipboard.write(value.trim());
      }
    }
  }
}

if (import.meta.main) {
  await main();
}
