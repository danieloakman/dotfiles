#! bun
import { noop, raise, randInteger, sleep } from '@danoaky/js-utils';
import { moveMouse } from './utils/mouse';
import meow from 'meow';

function toMs(str: string): number {
	if (/^\d+$/.test(str)) return parseInt(str);
	const n = str.match(/\d+/)?.[0] ?? raise(`Invalid arg "${str}"`);
	if (str.endsWith('ms')) return parseInt(n);
	if (str.endsWith('s')) return parseInt(n) * 1000;
	if (str.endsWith('m')) return parseInt(n) * 1000 * 60;
	if (str.endsWith('h')) return parseInt(n) * 1000 * 60 * 60;
	if (str.endsWith('d')) return parseInt(n) * 1000 * 60 * 60 * 24;
	raise(`Invalid arg "${str}"`);
}

function prettyTime(ms: number): string {
	if (ms < 1000) return `${ms}ms`;
	if (ms < 1000 * 60) return `${ms / 1000}s`;
	if (ms < 1000 * 60 * 60) return `${ms / 1000 / 60}m`;
	if (ms < 1000 * 60 * 60 * 24) return `${ms / 1000 / 60 / 60}h`;
	return `${ms / 1000 / 60 / 60 / 24}d`;
}

if (import.meta.main) {
	const {
		flags: { duration, interval, silent }
	} = meow(
		`
    Help:
      -d, --duration    How long the mouse is moved for (500ms, 1s, 1m, etc).
      -i, --interval    How often the mouse is moved, as in, time inbetween each move (500ms, 1s, 1m, etc).
      -s, --silent      Silent mode, no output.
    `,
		{
			importMeta: import.meta,
			flags: {
				duration: {
					type: 'string',
					shortFlag: 'd',
					default: '1d'
				},
				interval: {
					type: 'string',
					shortFlag: 'i',
					default: '1m'
				},
				silent: {
					type: 'boolean',
					shortFlag: 's',
					default: false
				}
			}
		}
	);
	const d = toMs(duration);
	const i = toMs(interval);
	if (silent) console.log = noop;
	console.log(`Moving mouse for ${prettyTime(d)} with interval ${prettyTime(i)}.`);
	sleep(d).then(() => {
		console.log('Done');
		process.exit(0);
	});
	while (true) {
		const x = randInteger(-50, 50);
		const y = randInteger(-50, 50);
		console.log(`Moving mouse ${x}x, ${y}y`);
		await moveMouse(x, y);
		await sleep(i);
	}
}
