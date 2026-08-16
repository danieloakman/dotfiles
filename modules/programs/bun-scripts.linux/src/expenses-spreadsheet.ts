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

const EDIT_FILE = '/tmp/expenses-spreadsheet.csv';

const cellSchema = z.union([z.string(), z.number(), z.boolean()]);
const readSchema = z.object({
	values: z.array(z.array(cellSchema)).optional()
});

type Cell = string | number | boolean;

function csvEscape(cell: string): string {
	if (/[",\n\r]/.test(cell)) return `"${cell.replaceAll('"', '""')}"`;
	return cell;
}

function toCsv(rows: Cell[][]): string {
	const width = Math.max(0, ...rows.map((row) => row.length));
	return (
		rows
			.map((row) =>
				Array.from({ length: width }, (_, i) => csvEscape(String(row[i] ?? ''))).join(',')
			)
			.join('\n') + (rows.length ? '\n' : '')
	);
}

function parseCsv(text: string): string[][] {
	const rows: string[][] = [];
	let row: string[] = [];
	let cell = '';
	let inQuotes = false;

	for (let i = 0; i < text.length; i++) {
		const c = text[i]!;
		if (inQuotes) {
			if (c === '"') {
				if (text[i + 1] === '"') {
					cell += '"';
					i++;
				} else {
					inQuotes = false;
				}
			} else {
				cell += c;
			}
			continue;
		}
		if (c === '"') {
			inQuotes = true;
			continue;
		}
		if (c === ',') {
			row.push(cell);
			cell = '';
			continue;
		}
		if (c === '\n' || c === '\r') {
			if (c === '\r' && text[i + 1] === '\n') i++;
			row.push(cell);
			cell = '';
			if (row.some((value) => value !== '')) rows.push(row);
			row = [];
			continue;
		}
		cell += c;
	}

	if (cell !== '' || row.length > 0) {
		row.push(cell);
		if (row.some((value) => value !== '')) rows.push(row);
	}
	return rows;
}

function todayDate(): string {
	const now = new Date();
	return `${now.getMonth() + 1}/${now.getDate()}/${now.getFullYear()}`;
}

async function fetchRows(): Promise<Cell[][]> {
	const data = await gwsJson(
		[
			'sheets',
			'spreadsheets',
			'values',
			'get',
			'--params',
			JSON.stringify({
				spreadsheetId: EXPENSES_SPREADSHEET_ID,
				range: EXPENSES_LIST_RANGE,
				valueRenderOption: 'FORMULA',
				dateTimeRenderOption: 'FORMATTED_STRING'
			}),
			'--format',
			'json'
		],
		readSchema
	);
	return data.values ?? [];
}

async function saveRows(rows: string[][]) {
	await gwsJson(
		[
			'sheets',
			'spreadsheets',
			'values',
			'clear',
			'--params',
			JSON.stringify({ spreadsheetId: EXPENSES_SPREADSHEET_ID, range: EXPENSES_LIST_RANGE }),
			'--json',
			'{}',
			'--format',
			'json'
		],
		z.unknown()
	);

	if (rows.length === 0) return;

	await gwsJson(
		[
			'sheets',
			'spreadsheets',
			'values',
			'update',
			'--params',
			JSON.stringify({
				spreadsheetId: EXPENSES_SPREADSHEET_ID,
				range: EXPENSES_APPEND_RANGE,
				valueInputOption: 'USER_ENTERED'
			}),
			'--json',
			JSON.stringify({ values: rows }),
			'--format',
			'json'
		],
		z.unknown()
	);
}

async function add(input: string[]) {
	const [amount, description] = input;
	if (!amount || !description || input.length !== 2) {
		exit('Usage: expenses-spreadsheet add <amount> <description>');
	}

	const date = todayDate();
	await gwsJson(
		[
			'sheets',
			'+append',
			'--spreadsheet',
			EXPENSES_SPREADSHEET_ID,
			'--range',
			EXPENSES_APPEND_RANGE,
			'--json-values',
			JSON.stringify([['Dan', date, amount, description]]),
			'--format',
			'json'
		],
		z.unknown()
	);
	console.log(`Added: Dan / ${date} / ${amount} — ${description}`);
}

async function list() {
	process.stdout.write(toCsv(await fetchRows()));
}

async function edit() {
	const beforeRows = await fetchRows();
	await Bun.write(EDIT_FILE, toCsv(beforeRows));

	const lastLine = String(Math.max(1, beforeRows.length));
	const code = await Bun.spawn(
		['sh', '-c', '${EDITOR:-vi} "$1" "+$2"', 'sh', EDIT_FILE, lastLine],
		{
			stdin: 'inherit',
			stdout: 'inherit',
			stderr: 'inherit'
		}
	).exited;
	if (code !== 0) exit(`Editor exited with code ${code}`);

	const afterRows = parseCsv(await Bun.file(EDIT_FILE).text());
	if (JSON.stringify(afterRows) === JSON.stringify(beforeRows.map((row) => row.map(String)))) {
		console.log('No changes');
		return;
	}
	if (afterRows.length === 0) exit('Refusing to save empty sheet');

	await saveRows(afterRows);
	console.log(`Saved ${afterRows.length} rows to spreadsheet`);
}

async function main() {
	const cli = meow(
		`
Usage
  $ expenses-spreadsheet <command> ...

Commands
  add <amount> <description>    Append a row (Paid by Dan, Date = today)
  list                          Print the Expenses tab as CSV
  edit                          Edit Expenses in $EDITOR, then save back

Examples
  $ expenses-spreadsheet add 50.3 Kmart
  $ expenses-spreadsheet add "=30*2" "Shein - trotty's stuff"
  $ expenses-spreadsheet list
  $ expenses-spreadsheet edit
		`.trimStart(),
		{
			importMeta: import.meta,
			commands: ['add', 'list', 'edit'],
			flags: {
				help: { type: 'boolean', shortFlag: 'h', default: false }
			}
		}
	);

	if (!cli.command || cli.flags.help) cli.showHelp(cli.command ? 0 : 1);

	try {
		if (cli.command === 'add') await add(cli.input);
		else if (cli.command === 'list') await list();
		else if (cli.command === 'edit') await edit();
	} catch (err) {
		exit(err instanceof Error ? err.message : String(err));
	}
}

main();
