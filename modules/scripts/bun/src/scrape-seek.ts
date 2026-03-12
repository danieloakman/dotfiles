import type { Browser, BrowserContext } from 'playwright-core';
import { connectToBrowser, launchBrowser, newPage, takeScreenshot } from '../src/utils/browser';
import meow from 'meow';
import { deferral } from '@danoaky/js-utils/disposables';
import { $ } from 'bun';
import { existsSync } from 'fs';
import { selectJobSchema, type Job } from './db';
import { attempt, Dayjs, once, safeParseInt } from '@danoaky/js-utils';
import { getBestCodingModelId, structuredCompletion } from './utils/ai';
import { createJob, jobExists } from './db/jobs';
import { AUTH_FILE } from './utils/env';
import z from 'zod';
import { downloadResumeText } from './utils/my-resume';

export const SEEK_BASE_URL = 'https://www.seek.com.au';

const relevanceSchema = z
	.object({
		relevance: z
			.number()
			.min(0)
			.max(100)
			.describe("Relevance score to the user's resume (number between 0 and 100)")
	})
	.describe('Relevance');

const resumeText = once(downloadResumeText);

function parseJobId(href: string) {
	if (!href.includes('/job/')) return null;
	const url = new URL(href, SEEK_BASE_URL);
	return safeParseInt(url.pathname.split('/')[2] ?? '') ?? null;
}

export async function* scrapeSeekJobSearch(
	ctx: Browser | BrowserContext,
	url: string
): AsyncGenerator<{ id: number; url: string }> {
	console.log(`Scraping ${url}`);
	await using page = await newPage(ctx);
	await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 10000 });
	const currentUrl = new URL(url);

	const jobLocators = page.locator('a[href*="/job/"]');
	while (true) {
		const locators = await jobLocators.all();
		if (!locators.length) {
			console.log('No jobs found on page', currentUrl.toString());
			await takeScreenshot(page, 'no_jobs');
			break;
		}

		for (const locator of locators) {
			const href = await locator.getAttribute('href');
			if (!href) continue;
			const jobId = parseJobId(href);
			if (!jobId) continue;
			yield { id: jobId, url: new URL(href, SEEK_BASE_URL).toString() };
		}

		const pageNum = parseInt(currentUrl.searchParams.get('page') ?? '1');
		currentUrl.searchParams.set('page', (pageNum + 1).toString());
		const nextPageUrl = currentUrl.toString();
		console.log('Going to next page', nextPageUrl);
		await page.goto(nextPageUrl, { waitUntil: 'domcontentloaded', timeout: 10000 });
	}
}

export async function scrapeSeekJobPage(
	ctx: Browser | BrowserContext,
	id: number,
	url: string
): Promise<Job> {
	await using page = await newPage(ctx);
	await page.goto(url, {
		waitUntil: 'domcontentloaded',
		timeout: 10000
	});

	const { postedMsAgo, ...data } = await page.evaluate(
		() => {
			const $ = (selector: string): HTMLElement | null =>
				document.body.querySelector(selector) ?? null;
			const $$ = (selector: string) =>
				Array.from(document.body.querySelectorAll(selector)) as HTMLElement[];
			return {
				title: $('[data-automation="job-detail-title"]')?.innerText ?? null,
				company: $('[data-automation="advertiser-name"]')?.innerText ?? null,
				description: $('[data-automation="jobAdDetails"]')?.innerText ?? null,
				location: $('[data-automation="job-detail-location"]')?.innerText ?? null,
				isQuickApply:
					$('[data-automation="job-detail-apply"]')?.innerText.includes('Quick apply') ?? false,
				workType: $('[data-automation="job-detail-work-type"]')?.innerText ?? null,
				salary: $('[data-automation="job-detail-salary"]')?.innerText ?? null,
				applied: $('[id="applied-date-message"]')?.innerText.includes('applied') ?? false,
				postedMsAgo: (() => {
					const postedRe = /Posted (\d+)([dhms])? ago/;
					const text = $$('span')
						.find((el) => postedRe.test(el.innerText.trim()))
						?.innerText.trim();
					if (!text) return null;
					const [, n, unit] = text.match(postedRe) ?? [];
					const num = parseInt(n ?? '');
					if (isNaN(num)) return null;
					switch (unit) {
						case 'd':
							return num * 24 * 60 * 60 * 1000;
						case 'h':
							return num * 60 * 60 * 1000;
						case 'm':
							return num * 60 * 1000;
						case 's':
							return num * 1000;
						default:
							return null;
					}
				})()
			};
		},
		{ timeout: 5000 }
	);
	const {
		success: parsedJobSuccess,
		data: parsedJobData,
		error
	} = selectJobSchema.safeParse({
		id,
		url,
		relevance: -1, // Calculated later
		postedAt: postedMsAgo ? Dayjs().subtract(postedMsAgo, 'ms').toDate() : null,
		...data
	});
	if (!parsedJobSuccess || !parsedJobData.id)
		throw new Error(`Failed to scrape job ${url}, ${error?.message}`);

	// {
	// 	const content = await page.innerText('div[data-metrics-identifier="jobDetailsPage"]', {
	// 		timeout: 5000
	// 	});
	// 	if (content) {
	// 		const { status, data, error } = await attempt(
	// 			structuredCompletion(
	// 				await getBestCodingModelId(),
	// 				// models.data[0]?.id ?? raise('No model found'),
	// 				content,
	// 				selectJobSchema
	// 			)
	// 		);
	// 		if (status === 'success') return data;
	// 		else console.warn('Error parsing job', url, error);
	// 	}
	// }
	// throw new Error(`Failed to scrape job ${url}`);

	const relevancePrompt = `
Here is my current resume:
---
${await resumeText()}
---

Now find the relevance score (integer value between 0 and 100) of the following job description to my resume:
---
${parsedJobData.description}
---
	`;
	const { status: relevanceStatus, data: relevanceData } = await attempt(
		structuredCompletion(await getBestCodingModelId(), relevancePrompt, relevanceSchema)
	);
	if (relevanceStatus !== 'success') {
		console.warn(`Failed to calculate relevance for job url: ${url}, status: ${relevanceStatus}`);
		return parsedJobData;
	}
	const { relevance } = relevanceData;

	return {
		...parsedJobData,
		relevance: relevance < 1 && relevance > 0 ? relevance * 100 : relevance // Sometimes the llm returns a float
	};
}

type WorkType = 'full-time' | 'part-time' | 'contract-temp' | 'casual-vacation';
const WORK_TYPE_MAP: Record<WorkType, string> = {
	'full-time': '242',
	'part-time': '243',
	'contract-temp': '244',
	'casual-vacation': '245'
};

type WorkArrangement = 'on-site' | 'remote' | 'hybrid';
const WORK_ARRANGEMENT_MAP: Record<WorkArrangement, string> = {
	'on-site': '1',
	hybrid: '2',
	remote: '3'
};

const SALARY_TYPES = ['annual', 'hourly', 'monthly'] as const;
type SalaryType = (typeof SALARY_TYPES)[number];

//https://www.seek.com.au/typescript-jobs/in-New-South-Wales-NSW?salaryrange=160000-&salarytype=annual&savedsearchid=f35aca47-a101-434f-94b5-aefda01d19b5&sitekey=AU-Main&workarrangement=2%2C3&worktype=242%2C244
export function createSeekSearchUrl(
	query: string,
	{
		location,
		salaryRange,
		salaryType,
		workType,
		workArrangement,
		daterange
	}: {
		location?: string;
		salaryRange?: `${number | ''}-${number | ''}`;
		salaryType?: SalaryType;
		workType?: WorkType[];
		workArrangement?: WorkArrangement[];
		daterange?: number;
	} = {}
) {
	const url = new URL(
		[
			query.endsWith('-jobs') ? query : `${query}-jobs`,
			location && !location.startsWith('in-') ? `in-${location}` : location
		]
			.filter(Boolean)
			.join('/'),
		SEEK_BASE_URL
	);
	if (salaryRange) url.searchParams.set('salaryrange', salaryRange);
	if (salaryType || salaryRange) url.searchParams.set('salarytype', salaryType ?? 'annual');
	if (workType?.length)
		url.searchParams.set('worktype', workType.map((type) => WORK_TYPE_MAP[type]).join(','));
	if (workArrangement?.length)
		url.searchParams.set(
			'workarrangement',
			workArrangement.map((arrangement) => WORK_ARRANGEMENT_MAP[arrangement]).join(',')
		);
	if (daterange) url.searchParams.set('daterange', daterange.toString());
	return url.toString();
}

if (import.meta.main) {
	const {
		flags,
		input: searchQueries,
		showHelp
	} = meow(
		`
Usage
$ scrape-seek [options] <searchQueries...>

Options
--help, -h        Show help
--headless    Whether to run the browser in headless mode
--location, -l    Location to search for (default: any)
--salaryRange, --sr    Salary range to search for (default: any), example: 100000-200000
--salaryType, --st    Salary type to search for (default: annual), example: annual, hourly, monthly
--workType, --wt    Work type to search for (default: any)
--workArrangement, --wa    Work arrangement to search for (default: any)
--daterange, --dr    Jobs listed within the last X days (default: any), example: 30

Environment Variables
PLAYWRIGHT_AUTH_FILE     Path to an auth file to load

  `.trimStart(),
		{
			importMeta: import.meta,
			flags: {
				help: {
					type: 'boolean',
					default: false
				},
				headless: {
					type: 'boolean',
					default: false
				},
				remote: {
					type: 'string'
				},
				location: {
					type: 'string',
					shortFlag: 'l',
					default: ''
				},
				salaryRange: {
					type: 'string',
					shortFlag: 'sr',
					default: ''
				},
				salaryType: {
					choices: SALARY_TYPES as unknown as string[],
					shortFlag: 'st',
					type: 'string'
				},
				workType: {
					choices: Object.keys(WORK_TYPE_MAP) as WorkType[],
					shortFlag: 'wt',
					isMultiple: true,
					type: 'string',
					default: []
				},
				workArrangement: {
					choices: Object.keys(WORK_ARRANGEMENT_MAP) as WorkArrangement[],
					shortFlag: 'wa',
					isMultiple: true,
					type: 'string',
					default: []
				},
				daterange: {
					type: 'number',
					shortFlag: 'dr'
				}
			}
		}
	);
	if (flags.help) showHelp(0);
	if (!existsSync(AUTH_FILE)) await $`echo '{}' > ${AUTH_FILE}`;
	if (!searchQueries.length) throw new Error('No search queries provided');

	const urls = searchQueries.map((q) =>
		createSeekSearchUrl(q, {
			location: flags.location,
			// @ts-expect-error - assume correct type from cli
			salaryRange: flags.salaryRange,
			// @ts-expect-error - assume correct type from cli
			salaryType: flags.salaryType,
			// @ts-expect-error - assume correct type from cli
			workType: flags.workType,
			// @ts-expect-error - assume correct type from cli
			workArrangement: flags.workArrangement,
			daterange: flags.daterange
		})
	);

	await using defer = deferral();
	const browser = flags.remote
		? await connectToBrowser(flags.remote)
		: await launchBrowser({ headless: flags.headless });
	const context = await browser.newContext({ storageState: AUTH_FILE });
	defer(async () => {
		await context.storageState({ path: AUTH_FILE });
		await context.close();
		await browser.close();
	});
	for (const inputUrl of urls) {
		for await (const { url, id } of scrapeSeekJobSearch(context, inputUrl)) {
			if ((await jobExists(id)) || id < 100) continue;
			const job = await scrapeSeekJobPage(context, id, url);
			await createJob(job);
			console.log(`Inserted job ${id}, ${url}`);
		}
	}
}
