export function exit(message?: string, code = 1): never {
	if (message) console.error(message);
	process.exit(code);
}

/** Shared meow flag so `-h` / `--help` work the same on every script. */
export const helpFlag = {
	help: {
		type: 'boolean' as const,
		shortFlag: 'h' as const,
		default: false
	}
};
