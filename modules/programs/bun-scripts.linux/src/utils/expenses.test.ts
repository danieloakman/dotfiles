import { describe, expect, test as it } from 'bun:test';
import { canonicalPayer } from './expenses';

describe('canonicalPayer', () => {
	it('defaults the sheet names', () => {
		expect(canonicalPayer('Dan')).toBe('Dan');
		expect(canonicalPayer('trotty')).toBe('Trotty');
		expect(canonicalPayer('Sheridan')).toBe('Trotty');
		expect(canonicalPayer('someone')).toBeUndefined();
	});
});
