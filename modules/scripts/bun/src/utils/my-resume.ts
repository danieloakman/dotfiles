import { attempt, Dayjs } from '@danoaky/js-utils';
import { tmpdir } from '../utils/env';
import { join } from 'path';
import { existsSync } from 'fs';
import { $ } from 'bun';

export const RESUME_URL = 'https://danoaky.dev/resume.pdf';

export const defaultResumePath = () => join(tmpdir(), `resume-${Dayjs().format('YYYY-MM-DD')}.pdf`);

/**
 * Downloads the resume from the URL and saves it to the specified path.
 * @param path - The path to the resume file. Defaults to the default resume path.
 * @returns The path to the downloaded resume file.
 */
export async function downloadResume(path: string = defaultResumePath()) {
	if (existsSync(path)) return path;
	const { data: response, error: fetchError } = await attempt(fetch(RESUME_URL));
	if (fetchError || !response.ok)
		throw new Error(
			`Failed to download resume: ${response?.statusText ?? fetchError?.message ?? 'Unknown error'}`
		);
	const buffer = await response.arrayBuffer();
	await Bun.write(path, buffer);
	return path;
}

/**
 * Downloads the resume from the URL and saves it to the specified path, then converts it to text.
 * @param path - The path to the resume text file. Defaults to the default resume path with a .txt extension.
 * @returns The text content of the resume file.
 */
export async function downloadResumeText(path?: string): Promise<string> {
	const pdfPath = await downloadResume();
	path ??= defaultResumePath().replace('.pdf', '.txt');
	await $`pdftotext ${pdfPath} ${path}`;
	return Bun.file(path).text();
}
