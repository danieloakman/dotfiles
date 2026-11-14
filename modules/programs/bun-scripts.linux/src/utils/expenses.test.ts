import { describe, expect, test as it } from 'bun:test';
import { canonicalPayer } from './expenses';

describe('canonicalPayer', () => {
	it('maps known names case-insensitively', () => {
		expect(canonicalPayer('Dan')).toBe('Dan');
		expect(canonicalPayer('DANIEL')).toBe('Dan');
		expect(canonicalPayer('@daniel')).toBe('Dan');
		expect(canonicalPayer('trotty')).toBe('Trotty');
		expect(canonicalPayer('Sheridan')).toBe('Trotty');
		expect(canonicalPayer('@SHERIDAN')).toBe('Trotty');
		expect(canonicalPayer('someone')).toBeUndefined();
	});
});
