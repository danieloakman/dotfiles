import { Client } from 'basic-ftp';
import meow from 'meow';
import { Deferral } from '@danoaky/js-utils/disposables';
import micromatch from 'micromatch';
import * as Path from 'path';
import { homedir } from 'os';
import { attempt } from '@danoaky/js-utils';
import { mkdir } from 'fs/promises';

const DEFAULT_OUTPUT_DIR = Path.join(homedir(), 'Sync/3ds-backup');

function panic(message: string, code = 1): never {
	console.error(message);
	process.exit(code);
}

async function listFilesRecursive(client: Client, srcDir: string): Promise<string[]> {
	const { data: list, error } = await attempt(client.list(srcDir));
	if (error) panic(`Failed to list directory "${srcDir}": ${error.message}`);

	const files: string[] = [];
	for (const stat of list) {
		const srcPath = Path.join(srcDir, stat.name);
		if (stat.isDirectory) {
			files.push(...(await listFilesRecursive(client, srcPath)));
		} else if (stat.isFile) {
			files.push(srcPath);
		}
	}
	return files;
}

async function downloadFilesFrom(
	client: Client,
	srcDir: string,
	globFile: string[],
	destDir: string,
	{ dryRun = false }: { dryRun?: boolean } = {}
) {
	const { data: list, error } = await attempt(client.list(srcDir));
	if (error) panic(`Failed to list directory "${srcDir}": ${error.message}`);

	for (const stat of list) {
		if (!stat.isFile || !micromatch.isMatch(stat.name, globFile)) continue;
		const srcPath = Path.join(srcDir, stat.name);
		const destPath = Path.join(destDir, srcPath);
		if (dryRun) {
			console.log(`Would download file: "${destPath}"`);
			continue;
		}
		await mkdir(Path.dirname(destPath), { recursive: true });
		const { error } = await attempt(client.downloadTo(destPath, srcPath));
		if (error) panic(`Failed to download "${destPath}": ${error.message}`);
		console.log(`Downloaded file: "${destPath}"`);
	}
}

async function downloadDirFrom(
	client: Client,
	srcDir: string,
	destDir: string,
	{ dryRun = false }: { dryRun?: boolean } = {}
) {
	if (dryRun) {
		const files = await listFilesRecursive(client, srcDir);
		for (const srcPath of files) {
			console.log(`Would download file: "${Path.join(destDir, srcPath)}"`);
		}
		return;
	}

	const destPath = Path.join(destDir, srcDir); // Copy dir to same directory structure as the source directory
	const { error } = await attempt(client.downloadToDir(destPath, srcDir));
	if (error) panic(`Failed to download directory "${srcDir}": ${error.message}`);
	console.log(`Downloaded directory: "${destPath}"`);
}

if (import.meta.main) {
	const {
		input,
		flags: { verbose, user, password, dryRun, output = DEFAULT_OUTPUT_DIR }
	} = meow(
		{
			importMeta: import.meta,
			autoHelp: true,
			help: `
				Usage: 3ds-backup <ip:port> 

				Options:
				--help           Show help
				-u, --user       Username (default: anonymous)
				-p, --password   Password (default: empty)
				-v, --verbose    Show verbose output
				-n, --dry-run    List files that would be downloaded without writing them
				-o, --output     Output directory (default: ${DEFAULT_OUTPUT_DIR})
			`,
			flags: {
				verbose: {
					type: 'boolean',
					default: false,
					shortFlag: 'v'
				},
				dryRun: {
					type: 'boolean',
					default: false,
					shortFlag: 'n'
				},
				user: {
					type: 'string',
					shortFlag: 'u'
				},
				password: {
					type: 'string',
					shortFlag: 'p'
				},
				output: {
					type: 'string',
					shortFlag: 'o'
				}
			}
		}
	);

	const [host, port] = input[0]?.split(':') ?? [];
	if (!host || !port || isNaN(parseInt(port))) panic('Invalid input');

	console.log(`Connecting to ${host}:${port} as ${user ?? 'anonymous'}`);
	await using defer = new Deferral();
	const client = new Client(10000);
	client.ftp.verbose = verbose;
	await client
		.access({
			host,
			port: parseInt(port),
			user,
			password
		})
		.then(() => console.log(`Connected to ${host}:${port}`))
		.catch((err: Error) => panic(`Failed to access ${host}:${port}: ${err.message}`));
	defer.add(() => client.close());

	if (dryRun) console.log('Dry run: no files will be written');
	else await mkdir(output, { recursive: true });

	const options = { dryRun };
	await downloadDirFrom(client, '3ds/Checkpoint/saves', output, options);
	await downloadDirFrom(client, '3ds/open_agb_firm/saves', output, options);
	await downloadFilesFrom(client, 'roms/nds/saves', ['*.s*'], output, options);
	await downloadFilesFrom(client, 'roms/gba', ['*.s*'], output, options);
}
