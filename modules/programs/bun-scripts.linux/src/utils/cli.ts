export function exit(message?: string, code = 1): never {
	if (message) console.error(message);
	process.exit(code);
}
