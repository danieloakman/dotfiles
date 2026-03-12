import { Singleton, once } from '@danoaky/js-utils';
import { IS_ON_WAYLAND } from './env';
import { exec, spawn } from 'child_process';

export class XYDoTool extends Singleton {
	/** Whether to initialize the ydotool daemon. False by default. */
	static initYdoToolDaemon = false;

	protected readonly YDOTOOL_SOCKET = '/tmp/.ydotool_socket';
	protected readonly cleanupFns: (() => unknown)[] = [];

	protected ydotoolDaemon = once(async () => {
		const s = spawn(`sudo ydotoold -p ${this.YDOTOOL_SOCKET}`, { shell: true });
		let init = false;

		return new Promise<void>((resolve, reject) => {
			const destroy = () =>
				new Promise<void>((resolve, reject) => {
					if (s.killed) return resolve();
					s.on('close', (code) => {
						if (code !== 0) reject(`Daemon exited with code ${code}`);
						resolve();
					});
					s.kill();
				});

			const handler = (data: Buffer) => {
				const msg = data.toString();
				if (/you're advised to run this program as root|failed to open uinput/i.test(msg))
					reject(msg);
				else if (!init) {
					init = true;
					resolve();
					this.cleanupFns.push(destroy);
				}
			};

			s.stdout?.on('data', handler);
			s.on('message', handler);
			s.stderr?.on('data', handler);
		});
	});

	protected init = once(async () => {
		if (IS_ON_WAYLAND && XYDoTool.initYdoToolDaemon) await this.ydotoolDaemon();
	});

	protected constructor() {
		super();
		this.init();
	}

	static override async instance(): Promise<XYDoTool> {
		if (this._instance) return this._instance;
		return (this._instance = new XYDoTool());
	}

	async [Symbol.asyncDispose]() {
		for (const fn of this.cleanupFns) await fn();
		XYDoTool._instance = null;
	}

	/** Move mouse relative to current postiion. */
	async moveMouse(x: number, y: number) {
		await this.init();
		const p = exec(this.cmd(x, y), {
			shell: 'zsh',
			env: {
				...process.env,
				...(XYDoTool.initYdoToolDaemon ? { YDOTOOL_SOCKET: this.YDOTOOL_SOCKET } : {})
			}
		});
		return new Promise<void>((resolve, reject) => {
			p.on('error', reject);
			p.stdout?.on('data', (data: Buffer) => {
				console.log(data.toString());
			});
			p.stderr?.on('data', reject);
			p.on('close', resolve);
		});
	}

	private cmd(x: number | string, y: number | string) {
		if (IS_ON_WAYLAND)
			return `${XYDoTool.initYdoToolDaemon ? 'sudo ' : ''}ydotool mousemove -x ${x} -y ${y}`;
		return `xdotool mousemove_relative -- ${x} ${y}`;
	}
}

export default XYDoTool;
