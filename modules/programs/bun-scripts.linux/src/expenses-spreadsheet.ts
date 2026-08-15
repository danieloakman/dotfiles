#! bun
import meow from 'meow';
import { z } from 'zod';
import { exit } from './utils/cli';
import {
	EXPENSES_APPEND_RANGE,
	EXPENSES_LIST_RANGE,
	EXPENSES_SPREADSHEET_ID
} from './utils/expenses';
import { gwsJson } from './utils/gws';

const readSchema = z.object({
	values: z.array(z.array(z.union([z.string(), z.number(), z.boolean()]))).optional()
});

function csvEscape(cell: string): string {
	if (/[",\n\r]/.test(cell)) return `"${cell.replaceAll('"', '""')}"`;
	return cell;
}

function toCsv(rows: (string | number | boolean)[][]): string {
	const width = Math.max(0, ...rows.map((row) => row.length));
	return (
		rows
			.map((row) =>
				Array.from({ length: width }, (_, i) => csvEscape(String(row[i] ?? ''))).join(',')
			)
			.join('\n') + (rows.length ? '\n' : '')
	);
}

async function add(input: string[]) {
	const [amount, description] = input;
	if (!amount || !description || input.length !== 2) {
		exit('Usage: expenses-spreadsheet add <amount> <description>');
	}

	await gwsJson(
		[
			'sheets',
			'+append',
			'--spreadsheet',
			EXPENSES_SPREADSHEET_ID,
			'--range',
			EXPENSES_APPEND_RANGE,
			'--json-values',
			JSON.stringify([['', '', amount, description]]),
			'--format',
			'json'
		],
		z.unknown()
	);
	console.log(`Added: ${amount} — ${description}`);
}

async function list() {
	const data = await gwsJson(
		[
			'sheets',
			'+read',
			'--spreadsheet',
			EXPENSES_SPREADSHEET_ID,
			'--range',
			EXPENSES_LIST_RANGE,
			'--format',
			'json'
		],
		readSchema
	);
	process.stdout.write(toCsv(data.values ?? []));
}

async function main() {
	const cli = meow(
		`
Usage
  $ expenses-spreadsheet <command> ...

Commands
  add <amount> <description>    Append a row (Paid by / Date left blank)
  list                          Print the Expenses tab as CSV

Examples
  $ expenses-spreadsheet add 50.3 Kmart
  $ expenses-spreadsheet add "=30*2" "Shein - trotty's stuff"
  $ expenses-spreadsheet list
		`.trimStart(),
		{
			importMeta: import.meta,
			commands: ['add', 'list'],
			flags: {
				help: { type: 'boolean', shortFlag: 'h', default: false }
			}
		}
	);

	if (!cli.command || cli.flags.help) cli.showHelp(cli.command ? 0 : 1);

	try {
		if (cli.command === 'add') await add(cli.input);
		else if (cli.command === 'list') await list();
	} catch (err) {
		exit(err instanceof Error ? err.message : String(err));
	}
}

main();
