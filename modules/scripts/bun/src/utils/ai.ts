import { once, raise } from '@danoaky/js-utils';
import OpenAI from 'openai';
import { zodResponseFormat } from 'openai/helpers/zod';
import { z } from 'zod';

export type AIInput = { role: 'user' | 'system' | 'assistant'; content: string }[] | string;

const llamaSwap = new OpenAI({
	baseURL: 'http://localhost:11344/v1',
	apiKey: 'dummy'
});

export const listModels = once(() => llamaSwap.models.list());

const codingRe = /cod(ing|er)/i;
export const getBestCodingModelId = once(async () => {
	const models = await listModels();
	return models.data.find((model) => codingRe.test(model.id))?.id ?? raise('No coding model found');
});

export const getBiggestParameterModelId = once(async () => {
	const { data} = await listModels();
	return data[0]?.id ?? raise('No models found');
})

export function prompt(model: string, input: Exclude<AIInput, string>) {
	return llamaSwap.chat.completions.create({
		model,
		messages: input
	});
}

export async function structuredPrompt<T extends z.ZodTypeAny>(
	model: string,
	input: string,
	schema: T
) {
	// Use chat/completions (llama-swap) not responses API (not implemented by llama-swap)
	const completion = await llamaSwap.chat.completions.parse({
		model,
		messages: [
			{
				role: 'system',
				content:
					'You are an expert at extracting data from text. Respond only with valid JSON matching the requested schema.'
			},
			{ role: 'user', content: input }
		],
		response_format: zodResponseFormat(schema, schema?.description ?? 'output')
	});
	return completion.choices[0]?.message?.parsed ?? raise('No completion found');
}
