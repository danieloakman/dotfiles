import * as cheerio from 'cheerio';
import { safeParseInt } from '@danoaky/js-utils';

export const SEEK_BASE_URL = 'https://www.seek.com.au';
export const SEEK_GRAPHQL_URL = `${SEEK_BASE_URL}/graphql`;
export const SEEK_SEARCH_API_URL = `${SEEK_BASE_URL}/api/jobsearch/v5/search`;

const SEEK_UA =
	'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4.1 Safari/605.1.15';

export const WORK_TYPES = {
	'full-time': '242',
	'part-time': '243',
	'contract-temp': '244',
	'casual-vacation': '245'
} as const;
export type WorkType = keyof typeof WORK_TYPES;

export const WORK_ARRANGEMENTS = {
	'on-site': '1',
	hybrid: '2',
	remote: '3'
} as const;
export type WorkArrangement = keyof typeof WORK_ARRANGEMENTS;

export const SALARY_TYPES = ['annual', 'hourly', 'monthly'] as const;
export type SalaryType = (typeof SALARY_TYPES)[number];

export const SORT_MODES = ['ListedDate', 'KeywordRelevance'] as const;
export type SortMode = (typeof SORT_MODES)[number];

/** GraphQL fields verified against SEEK (introspection disabled). */
const JOB_DETAILS_QUERY = `
query jobDetails($jobId: ID!) {
  jobDetails(id: $jobId) {
    job {
      id
      title
      abstract
      content(platform: WEB)
      status
      isExpired
      isLinkOut
      phoneNumber
      listedAt { dateTimeUtc }
      expiresAt { dateTimeUtc }
      salary { label }
      workTypes { label }
      advertiser { id name isVerified }
      location { label }
      classifications { label(languageCode: "en") }
    }
  }
}
`.trim();

type SeekGraphqlJob = {
	id: string;
	title: string | null;
	abstract: string | null;
	content: string | null;
	status: string | null;
	isExpired: boolean | null;
	isLinkOut: boolean | null;
	phoneNumber: string | null;
	listedAt: { dateTimeUtc: string } | null;
	expiresAt: { dateTimeUtc: string } | null;
	salary: { label: string } | null;
	workTypes: { label: string } | null;
	advertiser: { id: string; name: string; isVerified: boolean } | null;
	location: { label: string } | null;
	classifications: Array<{ label: string }> | null;
};

export type SeekJobDetail = {
	id: number;
	url: string;
	title: string;
	company: string;
	advertiserVerified: boolean | null;
	description: string;
	abstract: string;
	location: string;
	salary: string;
	workType: string;
	classification: string;
	/** Quick Apply when the listing is not an external link-out. */
	isQuickApply: boolean;
	isExpired: boolean;
	status: string;
	phoneNumber: string;
	listedAt: string | null;
	expiresAt: string | null;
};

export type SeekSearchHit = {
	id: number;
	url: string;
	title: string;
	company: string;
	location: string;
	salary: string;
	workTypes: string[];
	workArrangement: string;
	listingDate: string;
	teaser: string;
	bulletPoints: string[];
	isFeatured: boolean;
};

export type SeekSearchParams = {
	keywords?: string;
	where?: string;
	salaryRange?: string;
	salaryType?: SalaryType;
	workType?: WorkType[];
	workArrangement?: WorkArrangement[];
	daterange?: number;
	page?: number;
	pageSize?: number;
	sortmode?: SortMode;
	classification?: string;
	subclassification?: string;
};

export type SeekSearchResult = {
	totalCount: number;
	page: number;
	pageSize: number;
	jobs: SeekSearchHit[];
};

type SeekSearchApiJob = {
	id: string;
	title?: string;
	companyName?: string;
	advertiser?: { description?: string };
	locations?: Array<{ label?: string }>;
	salaryLabel?: string;
	workTypes?: string[];
	workArrangements?: { displayText?: string };
	listingDate?: string;
	teaser?: string;
	bulletPoints?: string[];
	isFeatured?: boolean;
};

function seekHeaders(extra: HeadersInit = {}): HeadersInit {
	return {
		Accept: 'application/json',
		'User-Agent': SEEK_UA,
		Origin: SEEK_BASE_URL,
		Referer: `${SEEK_BASE_URL}/`,
		...extra
	};
}

function htmlToText(html: string): string {
	if (!html) return '';
	const $ = cheerio.load(html.replace(/&nbsp;/gi, ' '));
	$('br').replaceWith('\n');
	$('p, div, h1, h2, h3, h4, h5, h6, tr').each((_, el) => {
		$(el).append('\n');
	});
	$('li').each((_, el) => {
		$(el).prepend('- ').append('\n');
	});
	return $.text()
		.replace(/[ \t]+\n/g, '\n')
		.replace(/\n{3,}/g, '\n\n')
		.replace(/[ \t]{2,}/g, ' ')
		.trim();
}

export function seekJobUrl(id: number | string): string {
	return `${SEEK_BASE_URL}/job/${id}`;
}

export function parseSeekJobId(value: string): number | null {
	const trimmed = value.trim();
	if (/^\d+$/.test(trimmed)) return safeParseInt(trimmed) ?? null;
	const match = trimmed.match(/(?:\/job\/|jobId=)(\d{6,})/);
	return match?.[1] ? (safeParseInt(match[1]) ?? null) : null;
}

function normalizeSearchHit(job: SeekSearchApiJob): SeekSearchHit | null {
	const id = safeParseInt(job.id);
	if (!id) return null;
	return {
		id,
		url: seekJobUrl(id),
		title: job.title?.trim() || '',
		company: (job.companyName || job.advertiser?.description || '').trim(),
		location: job.locations?.[0]?.label?.trim() || '',
		salary: job.salaryLabel?.trim() || '',
		workTypes: job.workTypes ?? [],
		workArrangement: job.workArrangements?.displayText?.trim() || '',
		listingDate: job.listingDate || '',
		teaser: (job.teaser || '').trim(),
		bulletPoints: job.bulletPoints ?? [],
		isFeatured: Boolean(job.isFeatured)
	};
}

export async function searchSeekJobs(params: SeekSearchParams): Promise<SeekSearchResult> {
	const page = params.page ?? 1;
	const pageSize = params.pageSize ?? 20;
	const url = new URL(SEEK_SEARCH_API_URL);
	url.searchParams.set('siteKey', 'AU-Main');
	url.searchParams.set('sourcesystem', 'houston');
	url.searchParams.set('locale', 'en-AU');
	url.searchParams.set('page', String(page));
	url.searchParams.set('pageSize', String(pageSize));
	if (params.keywords) url.searchParams.set('keywords', params.keywords);
	if (params.where) url.searchParams.set('where', params.where);
	if (params.salaryRange) {
		url.searchParams.set('salaryrange', params.salaryRange);
		url.searchParams.set('salarytype', params.salaryType ?? 'annual');
	} else if (params.salaryType) {
		url.searchParams.set('salarytype', params.salaryType);
	}
	if (params.workType?.length)
		url.searchParams.set('worktype', params.workType.map((t) => WORK_TYPES[t]).join(','));
	if (params.workArrangement?.length)
		url.searchParams.set(
			'workarrangement',
			params.workArrangement.map((a) => WORK_ARRANGEMENTS[a]).join(',')
		);
	if (params.daterange != null) url.searchParams.set('daterange', String(params.daterange));
	if (params.sortmode) url.searchParams.set('sortmode', params.sortmode);
	if (params.classification) url.searchParams.set('classification', params.classification);
	if (params.subclassification) url.searchParams.set('subclassification', params.subclassification);

	const res = await fetch(url, { headers: seekHeaders() });
	if (!res.ok) throw new Error(`SEEK search HTTP ${res.status}: ${url}`);

	const body = (await res.json()) as {
		totalCount?: number;
		data?: SeekSearchApiJob[];
	};
	const jobs = (body.data ?? [])
		.map(normalizeSearchHit)
		.filter((j): j is SeekSearchHit => j != null);

	return {
		totalCount: body.totalCount ?? jobs.length,
		page,
		pageSize,
		jobs
	};
}

/** Fetch multiple pages until exhausted or `pages` is reached. */
export async function searchSeekJobsPages(
	params: SeekSearchParams & { pages?: number },
	{ delayMs = 400 }: { delayMs?: number } = {}
): Promise<SeekSearchResult> {
	const pages = Math.max(1, params.pages ?? 1);
	const pageSize = params.pageSize ?? 20;
	const seen = new Set<number>();
	const jobs: SeekSearchHit[] = [];
	let totalCount = 0;

	for (let page = 1; page <= pages; page++) {
		const result = await searchSeekJobs({ ...params, page, pageSize });
		totalCount = result.totalCount;
		for (const job of result.jobs) {
			if (seen.has(job.id)) continue;
			seen.add(job.id);
			jobs.push(job);
		}
		if (result.jobs.length === 0 || page * pageSize >= totalCount) break;
		if (page < pages && delayMs > 0) await Bun.sleep(delayMs);
	}

	return { totalCount, page: pages, pageSize, jobs };
}

export async function fetchSeekJobDetail(jobId: number | string): Promise<SeekJobDetail | null> {
	const id = String(jobId);
	const res = await fetch(SEEK_GRAPHQL_URL, {
		method: 'POST',
		headers: seekHeaders({ 'Content-Type': 'application/json' }),
		body: JSON.stringify({
			operationName: 'jobDetails',
			variables: { jobId: id },
			query: JOB_DETAILS_QUERY
		})
	});
	if (!res.ok) throw new Error(`SEEK GraphQL HTTP ${res.status} for job ${id}`);

	const body = (await res.json()) as {
		errors?: Array<{ message: string }>;
		data?: { jobDetails?: { job?: SeekGraphqlJob | null } | null };
	};
	if (body.errors?.length) throw new Error(body.errors[0]?.message ?? 'SEEK GraphQL error');

	const job = body.data?.jobDetails?.job;
	if (!job) return null;

	const numericId = safeParseInt(job.id) ?? safeParseInt(id);
	if (!numericId) throw new Error(`Invalid SEEK job id: ${job.id}`);

	const description = htmlToText(job.content ?? '') || (job.abstract ?? '').trim() || '';

	return {
		id: numericId,
		url: seekJobUrl(numericId),
		title: job.title?.trim() || '',
		company: job.advertiser?.name?.trim() || '',
		advertiserVerified: job.advertiser?.isVerified ?? null,
		description,
		abstract: (job.abstract ?? '').trim(),
		location: job.location?.label?.trim() || '',
		salary: job.salary?.label?.trim() || '',
		workType: job.workTypes?.label?.trim() || '',
		classification: (job.classifications ?? [])
			.map((c) => c.label)
			.filter(Boolean)
			.join('; '),
		isQuickApply: !(job.isLinkOut ?? false),
		isExpired: job.isExpired ?? false,
		status: job.status ?? '',
		phoneNumber: job.phoneNumber?.trim() || '',
		listedAt: job.listedAt?.dateTimeUtc ?? null,
		expiresAt: job.expiresAt?.dateTimeUtc ?? null
	};
}
