import { describe, test as it, expect } from 'bun:test';
import { structuredCompletion, getBestCodingModelId } from './ai';
import z from 'zod';

describe('ai', () => {
	it('structuredCompletion', async () => {
		const schema = z
			.object({
				places: z.array(
					z.object({
						city: z.string(),
						country: z.string(),
						coordinates: z.object({ latitude: z.number(), longitude: z.number() })
					})
				)
			})
			.describe('places');
		const res = await structuredCompletion(
			await getBestCodingModelId(),
			'France | Paris | 48.8566, 2.3522\nGermany | Berlin | 52.5244, 13.4105',
			schema
		);
		expect(res).toBeObject();
		expect(schema.safeParse(res).success).toBe(true);
	});
});
