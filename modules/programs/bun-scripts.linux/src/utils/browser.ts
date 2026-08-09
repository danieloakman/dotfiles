import {
	type Browser,
	chromium as playwright,
	type LaunchOptions,
	type Cookie,
	type BrowserContext,
	type Page
} from 'playwright-core';
import { attempt, clamp, Dayjs, once, Result } from '@danoaky/js-utils';
import { readFile } from 'fs/promises';
import * as Z from 'zod';
import { join } from 'path';
import { tmpdir } from 'os';

/**
 * Launches a browser with launch options handled internally for the most part.
 * @returns a browser instance that can be used with explicit resource management.
 * @example
 * ```ts
 * await using browser = await launchBrowser();
 * ```
 */
export async function launchBrowser(options: LaunchOptions = {}) {
	const browser = await playwright.launch(options);
	return Object.assign(browser, {
		[Symbol.asyncDispose]: async () => {
			await browser.close();
		}
	});
}

export async function connectToBrowser(endpointUrl: string) {
	return playwright.connect(endpointUrl, { timeout: 10000 });
}

export function launchBrowsers(
	count: number,
	options: LaunchOptions
): (() => Promise<Browser>)[] & AsyncDisposable {
	const browsers = Array.from({ length: clamp(count, 1, Infinity) }, () =>
		once(async () => playwright.launch(options))
	);
	return Object.assign(browsers, {
		[Symbol.asyncDispose]: async () => {
			await Promise.all(
				browsers.map((getBrowser) => getBrowser().then((b) => b.close().catch(() => null)))
			);
		}
	}) as (() => Promise<Browser>)[] & AsyncDisposable;
}

/**
 * Creates a new page in the browser.
 * @returns a page instance that can be used with explicit resource management.
 * @example
 * ```ts
 * await using page = await newPage(browser);
 * ```
 */
export async function newPage(browser: Browser | BrowserContext) {
	const page = await browser.newPage();
	return Object.assign(page, {
		[Symbol.asyncDispose]: async () => {
			await page.close();
		}
	});
}

const SAME_SITE_MAP: Record<string, Cookie['sameSite']> = {
	lax: 'Lax',
	strict: 'Strict',
	none: 'None',
	unspecified: 'None',
	no_restriction: 'None'
};

export const cookiesSchema = Z.array(
	Z.object({
		name: Z.string(),
		value: Z.string(),
		domain: Z.string(),
		path: Z.string().default('/'),
		expires: Z.number().optional(),
		expirationDate: Z.number().optional(),
		httpOnly: Z.boolean().default(false),
		secure: Z.boolean().default(false),
		sameSite: Z.string().transform((s, ctx) => {
			const value = SAME_SITE_MAP[s];
			if (!value) {
				ctx.addIssue({
					code: 'invalid_value',
					values: Object.keys(SAME_SITE_MAP),
					input: s,
					continue: false,
					message: 'Invalid sameSite value'
				});
				return Z.NEVER;
			}
			return value;
		})
	}).transform(({ expires, expirationDate, ...rest }) => ({
		...rest,
		// expires: Math.floor(expirationDate ?? expires ?? Date.now() + 1000 * 60 * 60 * 24 * 30),
		expires: Math.floor(Date.now() / 1000 + 365 * 24 * 60 * 60) // unix timestamp in seconds, year from now
	}))
);

export async function parseCookiesFile(path: string): Promise<Result<Cookie[], Error>> {
	const content = await readFile(path, 'utf-8');
	return attempt(() => {
		const parsed = JSON.parse(content.trim());
		return cookiesSchema.parse(parsed);
	});
}

export async function takeScreenshot(page: Page, name: string = 'screenshot') {
	const path = join(tmpdir(), `${Dayjs().format('YYYY-MM-DD_HH-mm-ss')}_${name}.png`);
	await page.screenshot({ path });
	console.log(`📸 ${path}`);
	return path;
}
