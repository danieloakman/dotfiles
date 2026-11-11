#! bun
import dayjs from 'dayjs';
import customParseFormat from 'dayjs/plugin/customParseFormat';
import meow from 'meow';
import { z } from 'zod';
import { exit, helpFlag } from './utils/cli';
import {
	EXPENSES_APPEND_RANGE,
	EXPENSES_LIST_RANGE,
	EXPENSES_SPREADSHEET_ID,
	canonicalPayer
} from './utils/expenses';
import { gwsJson } from './utils/gws';

dayjs.extend(customParseFormat);

const EDIT_FILE = '/tmp/expenses-spreadsheet.csv';

const cellSchema = z.union([z.string(), z.number(), z.boolean()]);
const readSchema = z.object({
	values: z.array(z.array(cellSchema)).optional()
});

type Cell = string | number | boolean;

/** Formats accepted by --date. Slash dates are day-first (D/M/YYYY). */
const DATE_INPUT_FORMATS = [
	'YYYY-MM-DD',
	'D/M/YYYY',
	'DD/MM/YYYY',
	'D-M-YYYY',
	'DD-MM-YYYY',
	'D MMM YYYY',
	'DD MMM YYYY',
	'D MMMM YYYY',
	'DD MMMM YYYY'
] as const;

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

/** Sheet Date column style used by existing rows from `add` (M/D/YYYY). */
function formatSheetDate(d: dayjs.Dayjs): string {
	return `${d.month() + 1}/${d.date()}/${d.year()}`;
}

function todayDate(): string {
	return formatSheetDate(dayjs());
}

function resolveDate(raw?: string): string {
	if (!raw?.trim()) return todayDate();
	const input = raw.trim();
	for (const format of DATE_INPUT_FORMATS) {
		const parsed = dayjs(input, format, true);
		if (parsed.isValid()) return formatSheetDate(parsed);
	}
	exit(
		`Invalid --date "${input}". Use YYYY-MM-DD or D/M/YYYY (e.g. 2026-10-28 or 28/10/2026).`
	);
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

async function add(input: string[], paidBy: string, dateFlag?: string) {
	const [amount, description] = input;
	if (!amount || !description || input.length !== 2) {
		exit(
			'Usage: expenses-spreadsheet add [--paid-by Dan|Trotty] [--date YYYY-MM-DD] <amount> <description>'
		);
	}
	const payer = canonicalPayer(paidBy);
	if (!payer) exit('Paid by must be Dan or Trotty');

	const date = resolveDate(dateFlag);
	await gwsJson(
		[
			'sheets',
			'+append',
			'--spreadsheet',
			EXPENSES_SPREADSHEET_ID,
			'--range',
			EXPENSES_APPEND_RANGE,
			'--json-values',
			JSON.stringify([[payer, date, amount, description]]),
			'--format',
			'json'
		],
		z.unknown()
	);
	console.log(`Added: ${payer} / ${date} / ${amount} — ${description}`);
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
  add <amount> <description>    Append a row (Date = today, or --date). Paid by Dan unless --paid-by is set
  list                          Print the Expenses tab as CSV
  edit                          Edit Expenses in $EDITOR, then save back

Options
  -h, --help                    Show help
  -p, --paid-by <name>          Dan or Trotty (Sheridan). Default: Dan
  -d, --date <date>             Row date (YYYY-MM-DD or D/M/YYYY). Default: today

Examples
  $ expenses-spreadsheet add 50.3 Kmart
  $ expenses-spreadsheet add --paid-by Trotty 0 "TODO Kmart, $24 Trotty"
  $ expenses-spreadsheet add --date 2026-10-28 --paid-by Trotty 19.08 "TSUTAKOTSU - Visa Purchase"
  $ expenses-spreadsheet add "=30*2" "Shein - trotty's stuff"
  $ expenses-spreadsheet list
  $ expenses-spreadsheet edit
		`.trimStart(),
		{
			importMeta: import.meta,
			// Parse command from input ourselves so flags work before or after it
			// (meow's `commands` option only accepts flags placed before the command).
			flags: {
				...helpFlag,
				paidBy: {
					type: 'string',
					shortFlag: 'p',
					default: 'Dan'
				},
				date: {
					type: 'string',
					shortFlag: 'd'
				}
			}
		}
	);

	const [command, ...args] = cli.input;
	if (!command || cli.flags.help) cli.showHelp(command ? 0 : 1);
	if (command !== 'add' && command !== 'list' && command !== 'edit') {
		exit(`Unknown command: ${command}`);
	}

	try {
		if (command === 'add') await add(args, cli.flags.paidBy, cli.flags.date);
		else if (command === 'list') await list();
		else if (command === 'edit') await edit();
	} catch (err) {
		exit(err instanceof Error ? err.message : String(err));
	}
}

main();
