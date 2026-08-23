#! bun
import { $, file, write } from 'bun';
import { cancel, isCancel, multiselect } from '@clack/prompts';
import { existsSync } from 'fs';
import { basename, dirname, join, resolve } from 'path';
import meow from 'meow';
import { z } from 'zod';
import { exit } from './utils/cli';
import { configdir } from './utils/env';

let verbose = false;

function vlog(message: string): void {
	if (verbose) console.error(message);
}

const prefsSchema = z.object({
	repos: z.record(z.string(), z.object({ copy: z.array(z.string()) })).default({})
});

type Prefs = z.infer<typeof prefsSchema>;

const prefsFile = () => join(configdir(), 'nwt.json');

async function loadPrefs(): Promise<Prefs> {
	const path = prefsFile();
	vlog(`Loading prefs from ${path}`);
	const f = file(path, { type: 'application/json' });
	if (!(await f.exists())) return { repos: {} };
	const raw = await f.json().catch(() => null);
	const parsed = prefsSchema.safeParse(raw);
	if (!parsed.success) {
		console.error(`Ignoring invalid prefs at ${path}: ${parsed.error.message}`);
		return { repos: {} };
	}
	return parsed.data;
}

async function savePrefs(prefs: Prefs): Promise<void> {
	const path = prefsFile();
	vlog(`Saving prefs to ${path}`);
	await write(path, JSON.stringify(prefs, null, 2) + '\n');
}

function slugifyBranch(branch: string): string {
	return branch
		.replace(/[^a-zA-Z0-9._-]+/g, '-')
		.replace(/-+/g, '-')
		.replace(/^-|-$/g, '');
}

async function git(args: string[], cwd?: string): Promise<string> {
	vlog(`$ git ${args.join(' ')}${cwd ? `  (cwd: ${cwd})` : ''}`);
	const proc = Bun.spawn(['git', ...args], {
		cwd,
		stdout: 'pipe',
		stderr: 'pipe'
	});
	const [stdout, stderr, exitCode] = await Promise.all([
		new Response(proc.stdout).text(),
		new Response(proc.stderr).text(),
		proc.exited
	]);
	if (exitCode !== 0) {
		exit(stderr.trim() || stdout.trim() || `git ${args.join(' ')} failed`);
	}
	return stdout.trim();
}

async function gitOk(args: string[], cwd?: string): Promise<boolean> {
	vlog(`$ git ${args.join(' ')}${cwd ? `  (cwd: ${cwd})` : ''}`);
	const proc = Bun.spawn(['git', ...args], {
		cwd,
		stdout: 'ignore',
		stderr: 'ignore'
	});
	return (await proc.exited) === 0;
}

async function getInvokingRoot(): Promise<string> {
	return resolve(await git(['rev-parse', '--show-toplevel']));
}

async function getPrimaryRoot(cwd: string): Promise<string> {
	const porcelain = await git(['worktree', 'list', '--porcelain'], cwd);
	const match = porcelain.match(/^worktree (.+)$/m);
	if (!match?.[1]) exit('Could not determine primary worktree path');
	return resolve(match[1]);
}

async function listTopLevelIgnored(root: string): Promise<string[]> {
	// Avoid -u/--untracked-files=all so ignored directories stay as one entry
	// (e.g. `!! tmp/`) instead of every nested file. Only accept paths with a
	// single component so nested ignores under tracked dirs (e.g.
	// `!! modules/scripts/bun/node_modules/`) do not surface as `modules`.
	const out = await git(['status', '--ignored', '--porcelain=v1'], root);
	const names = new Set<string>();
	for (const line of out.split('\n')) {
		if (!line.startsWith('!! ')) continue;
		const rel = line.slice(3).replace(/\/$/, '');
		if (!rel || rel.includes('/') || rel === '.git') continue;
		if (existsSync(join(root, rel))) names.add(rel);
	}
	return [...names].sort((a, b) => a.localeCompare(b));
}

function selectNamedIgnored(candidates: string[], inputs: string[]): string[] {
	const selected: string[] = [];
	for (const input of inputs) {
		const name = input.replace(/^\.\//, '').replace(/\/$/, '');
		if (candidates.includes(name)) {
			if (!selected.includes(name)) selected.push(name);
			continue;
		}
		console.error(`Not a top-level ignored path: ${input}`);
	}
	return selected;
}

async function branchExists(branch: string, cwd: string): Promise<boolean> {
	return gitOk(['show-ref', '--verify', '--quiet', `refs/heads/${branch}`], cwd);
}

function inHerdr(): boolean {
	return process.env.HERDR_ENV === '1';
}

async function addWorktree(
	targetPath: string,
	branch: string,
	cwd: string,
	create: boolean
): Promise<void> {
	const args = create
		? ['worktree', 'add', '-b', branch, targetPath]
		: ['worktree', 'add', targetPath, branch];
	await git(args, cwd);
}

async function herdrCreateWorktree(
	targetPath: string,
	branch: string,
	cwd: string
): Promise<void> {
	const args = [
		'worktree',
		'create',
		'--cwd',
		cwd,
		'--branch',
		branch,
		'--path',
		targetPath,
		'--focus'
	];
	vlog(`$ herdr ${args.join(' ')}`);
	const proc = Bun.spawn(['herdr', ...args], {
		stdout: 'pipe',
		stderr: 'pipe'
	});
	const [stdout, stderr, exitCode] = await Promise.all([
		new Response(proc.stdout).text(),
		new Response(proc.stderr).text(),
		proc.exited
	]);
	if (exitCode !== 0) {
		exit(stderr.trim() || stdout.trim() || `herdr ${args.join(' ')} failed`);
	}
	if (verbose && stdout.trim()) console.error(stdout.trim());
}

async function copySelected(
	sourceRoot: string,
	targetRoot: string,
	names: string[]
): Promise<void> {
	for (const name of names) {
		const from = join(sourceRoot, name);
		const to = join(targetRoot, name);
		if (!existsSync(from)) {
			console.error(`Skipping missing path: ${name}`);
			continue;
		}
		vlog(`$ cp -a ${from} ${to}`);
		const result = await $`cp -a ${from} ${to}`.nothrow().quiet();
		if (result.exitCode !== 0) {
			exit(result.stderr.toString().trim() || `Failed to copy ${name}`);
		}
	}
}

async function main() {
	const cli = meow(
		`
    -- Git worktree helper with ignored-file copy --

    Usage:
    $ nwt <branch> [paths...] [Options]
    $ nwt <branch> --interactive [Options]

    Examples:
    $ nwt feat/foo tmp .claude
    $ nwt feat/foo .cl*          # shell expands, then we copy .claude
    $ nwt feat/foo '.cl*'        # quoted → no match
    $ nwt feat/foo -i            # interactively select ignored paths

    Inside herdr (HERDR_ENV=1), creates via \`herdr worktree create --path\`
    so the checkout opens as a grouped workspace; otherwise uses git worktree.

    Options:
    --help, -h           Show help
    --path, -p           Override derived worktree path
    --dry-run, -n        Show what would happen without making changes
    --verbose, -v        Print detailed progress to stderr
    --interactive, -i    Interactively select ignored paths to copy
  `,
		{
			importMeta: import.meta,
			flags: {
				help: {
					type: 'boolean',
					shortFlag: 'h'
				},
				path: {
					type: 'string',
					shortFlag: 'p'
				},
				dryRun: {
					type: 'boolean',
					shortFlag: 'n',
					default: false
				},
				verbose: {
					type: 'boolean',
					shortFlag: 'v',
					default: false
				},
				interactive: {
					type: 'boolean',
					shortFlag: 'i',
					default: false
				}
			}
		}
	);

	if (cli.flags.help) {
		console.error(cli.help);
		return;
	}

	verbose = cli.flags.verbose;
	const dryRun = cli.flags.dryRun;
	const interactive = cli.flags.interactive;
	const branch = cli.input[0];
	const paths = cli.input.slice(1);
	if (!branch) {
		exit('Usage: nwt <branch> [paths...] [--interactive] [--path <dir>] [--dry-run] [--verbose]');
	}
	if (interactive && paths.length > 0) {
		exit('Do not pass paths with --interactive');
	}

	const invokingRoot = await getInvokingRoot();
	vlog(`Invoking root: ${invokingRoot}`);
	const primaryRoot = await getPrimaryRoot(invokingRoot);
	vlog(`Primary root: ${primaryRoot}`);
	const slug = slugifyBranch(branch);
	if (!slug) exit(`Could not derive a path slug from branch name: ${branch}`);
	vlog(`Branch slug: ${slug}`);

	const targetPath = resolve(
		cli.flags.path ?? join(dirname(primaryRoot), `${basename(primaryRoot)}_${slug}`)
	);
	vlog(`Target path: ${targetPath}`);

	if (existsSync(targetPath)) exit(`Worktree path already exists: ${targetPath}`);

	let selected: string[] = [];
	let prefs: Prefs | undefined;

	if (interactive || paths.length > 0) {
		const candidates = await listTopLevelIgnored(invokingRoot);
		vlog(
			candidates.length > 0
				? `Ignored candidates: ${candidates.join(', ')}`
				: 'Ignored candidates: (none)'
		);

		if (candidates.length === 0) {
			console.error('No top-level ignored paths found to copy.');
		} else if (interactive) {
			prefs = await loadPrefs();
			const saved = prefs.repos[primaryRoot]?.copy ?? [];
			const initialValues = saved.filter((name) => candidates.includes(name));
			vlog(
				initialValues.length > 0
					? `Preselected from prefs: ${initialValues.join(', ')}`
					: 'Preselected from prefs: (none)'
			);
			if (!process.stdin.isTTY) {
				exit('Interactive selection required, but stdin is not a TTY. Run in a terminal.');
			}
			const result = await multiselect({
				message: 'Copy ignored paths into the new worktree',
				options: candidates.map((value) => ({ value, label: value })),
				initialValues,
				required: false,
				output: process.stderr
			});
			if (isCancel(result)) {
				cancel('Cancelled.', { output: process.stderr });
				exit(undefined, 1);
			}
			selected = result;
		} else {
			selected = selectNamedIgnored(candidates, paths);
		}
	}
	vlog(selected.length > 0 ? `Selected: ${selected.join(', ')}` : 'Selected: (none)');

	const useHerdr = inHerdr();
	vlog(useHerdr ? 'Detected herdr (HERDR_ENV=1)' : 'Not in herdr; using git worktree');

	if (dryRun) {
		console.error('Dry run — no changes will be made.');
		if (useHerdr) {
			console.error(
				`Would run: herdr worktree create --cwd ${invokingRoot} --branch ${branch} --path ${targetPath} --focus`
			);
		} else {
			const exists = await branchExists(branch, invokingRoot);
			vlog(exists ? `Branch exists: ${branch}` : `Branch does not exist: ${branch}`);
			console.error(
				exists
					? `Would attach worktree at ${targetPath} to existing branch ${branch}`
					: `Would create branch ${branch} from HEAD and add worktree at ${targetPath}`
			);
		}
		console.error(
			selected.length > 0 ? `Would copy: ${selected.join(', ')}` : 'Would copy: (nothing)'
		);
		if (interactive) console.error(`Would update prefs for ${primaryRoot}`);
		process.stdout.write(`${targetPath}\n`);
		return;
	}

	if (useHerdr) {
		await herdrCreateWorktree(targetPath, branch, invokingRoot);
	} else {
		const exists = await branchExists(branch, invokingRoot);
		vlog(exists ? `Branch exists: ${branch}` : `Branch does not exist: ${branch}`);
		await addWorktree(targetPath, branch, invokingRoot, !exists);
	}
	await copySelected(invokingRoot, targetPath, selected);

	if (interactive && prefs) {
		prefs.repos[primaryRoot] = { copy: selected };
		await savePrefs(prefs);
	}

	process.stdout.write(`${targetPath}\n`);
}

if (import.meta.main) {
	main().catch((err) => {
		exit(err instanceof Error ? err.message : String(err));
	});
}
