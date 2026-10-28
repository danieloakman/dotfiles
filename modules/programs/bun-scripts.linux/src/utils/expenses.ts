export const EXPENSES_SPREADSHEET_ID = '1Q0OmgTsv0u2DVHRJl93DvFU3Melazld78_bBAd5bo5s';
export const EXPENSES_APPEND_RANGE = 'Expenses!A1';
export const EXPENSES_LIST_RANGE = 'Expenses!A:D';

/** Sheet names for the Paid by column. Sheridan is stored as Trotty. */
export function canonicalPayer(raw: string): string | undefined {
	switch (raw.trim().toLowerCase()) {
		case 'dan':
			return 'Dan';
		case 'trotty':
		case 'sheridan':
			return 'Trotty';
		default:
			return undefined;
	}
}
