import meow from 'meow';
import { exit } from './utils/cli';
import {
	SALARY_TYPES,
	SORT_MODES,
	WORK_ARRANGEMENTS,
	WORK_TYPES,
	fetchSeekJobDetail,
	parseSeekJobId,
	searchSeekJobsPages,
	type SalaryType,
	type SeekJobDetail,
	type SeekSearchHit,
	type SortMode,
	type WorkArrangement,
	type WorkType
} from './utils/seek';

function printTable(jobs: SeekSearchHit[]) {
	if (!jobs.length) {
		console.log('No jobs found.');
		return;
	}
	for (const [i, j] of jobs.entries()) {
		console.log(`${i + 1}. ${j.title}  —  ${j.company}`);
		const meta = [j.location, j.workArrangement, j.salary, j.workTypes.join(', ')]
			.filter(Boolean)
			.join('  ');
		if (meta) console.log(`   ${meta}`);
		console.log(`   ${j.url}`);
		if (j.teaser) console.log(`   ${j.teaser.slice(0, 140)}`);
		console.log();
	}
}

function printDetailTable(job: SeekJobDetail) {
	const verified = job.advertiserVerified ? '  ✓verified' : '';
	console.log(`${job.title}  —  ${job.company}${verified}`);
	const meta = [job.location, job.salary, job.workType, job.classification, `status: ${job.status}`]
		.filter(Boolean)
		.join('  ');
	console.log(meta);
	if (job.phoneNumber) console.log(`Recruiter phone: ${job.phoneNumber}`);
	console.log(
		[
			job.url,
			job.isQuickApply ? 'Quick Apply' : 'Link-out',
			job.isExpired ? 'EXPIRED' : null,
			job.listedAt ? `listed ${job.listedAt}` : null
		]
			.filter(Boolean)
			.join('  ')
	);
	console.log();
	console.log(job.description);
}

async function runDetail(argv: string[]) {
	const { flags, input, showHelp } = meow(
		`
Usage
  $ seek-api detail <id|url>

Fetch one SEEK job's full description via GraphQL.
JSON on stdout by default; use --table for human output.

Options
  --help, -h     Show help
  --table, -t    Human-readable output instead of JSON

Examples
  $ seek-api detail 93933486
  $ seek-api detail https://www.seek.com.au/job/93933486
		`.trimStart(),
		{
			importMeta: import.meta,
			argv,
			flags: {
				help: { type: 'boolean', shortFlag: 'h', default: false },
				table: { type: 'boolean', shortFlag: 't', default: false }
			}
		}
	);

	if (flags.help) showHelp(0);

	const raw = input.join(' ').trim();
	if (!raw) {
		showHelp(1);
		exit('Provide a job id or URL');
	}

	const jobId = parseSeekJobId(raw);
	if (!jobId) exit(`Couldn't extract a job id from '${raw}'`, 2);

	try {
		const job = await fetchSeekJobDetail(jobId);
		if (!job) exit(`Job ${jobId} not found (may be expired/removed)`, 1);
		if (flags.table) printDetailTable(job);
		else console.log(JSON.stringify(job, null, 2));
	} catch (err) {
		exit(`Detail fetch failed for ${jobId}: ${err instanceof Error ? err.message : err}`);
	}
}

async function runSearch(argv: string[]) {
	const { flags, input, showHelp } = meow(
		`
Usage
  $ seek-api search [options] <keywords...>

Search SEEK AU via the public JSON API.
JSON on stdout by default; use --table for a human listing.

Options
  --help, -h                 Show help
  --where, -w <location>     Location, e.g. "New South Wales", "Sydney NSW", "All Australia"
  --salary-range, --sr       Salary range, e.g. 170000- or 170000-220000
  --salary-type, --st        annual | hourly | monthly (default annual when range set)
  --work-type, --wt          full-time | part-time | contract-temp | casual-vacation (repeatable)
  --work-arrangement, --wa   on-site | hybrid | remote (repeatable)
  --daterange, --dr <n>      Listed within last N days
  --sortmode, --sm           ListedDate | KeywordRelevance
  --classification <id>      e.g. 6281 (ICT)
  --subclassification <id>   Child classification id
  --pages, -p <n>            Result pages to fetch (default 1, ~20/page)
  --page-size <n>            Results per page (default 20)
  --table, -t                Human-readable output instead of JSON

Examples
  $ seek-api search typescript --where "New South Wales" --sr 170000- --wt full-time --wa hybrid --wa remote --dr 7
  $ seek-api search "senior software engineer" -w "Sydney NSW" --sm ListedDate --pages 2
		`.trimStart(),
		{
			importMeta: import.meta,
			argv,
			flags: {
				help: { type: 'boolean', shortFlag: 'h', default: false },
				where: { type: 'string', shortFlag: 'w', default: '' },
				salaryRange: { type: 'string', aliases: ['sr'], default: '' },
				salaryType: {
					type: 'string',
					aliases: ['st'],
					choices: [...SALARY_TYPES]
				},
				workType: {
					type: 'string',
					aliases: ['wt'],
					isMultiple: true,
					choices: Object.keys(WORK_TYPES) as WorkType[],
					default: []
				},
				workArrangement: {
					type: 'string',
					aliases: ['wa'],
					isMultiple: true,
					choices: Object.keys(WORK_ARRANGEMENTS) as WorkArrangement[],
					default: []
				},
				daterange: { type: 'number', aliases: ['dr'] },
				sortmode: {
					type: 'string',
					aliases: ['sm'],
					choices: [...SORT_MODES]
				},
				classification: { type: 'string', default: '' },
				subclassification: { type: 'string', default: '' },
				pages: { type: 'number', shortFlag: 'p', default: 1 },
				pageSize: { type: 'number', default: 20 },
				table: { type: 'boolean', shortFlag: 't', default: false }
			}
		}
	);

	if (flags.help) showHelp(0);

	const keywords = input.join(' ').trim();
	if (!keywords) {
		showHelp(1);
		exit('Provide search keywords');
	}

	try {
		const result = await searchSeekJobsPages({
			keywords,
			where: flags.where || undefined,
			salaryRange: flags.salaryRange || undefined,
			salaryType: flags.salaryType as SalaryType | undefined,
			workType: flags.workType as WorkType[],
			workArrangement: flags.workArrangement as WorkArrangement[],
			daterange: flags.daterange,
			pages: flags.pages,
			pageSize: flags.pageSize,
			sortmode: flags.sortmode as SortMode | undefined,
			classification: flags.classification || undefined,
			subclassification: flags.subclassification || undefined
		});

		if (flags.table) {
			console.error(`Found ${result.totalCount} jobs (showing ${result.jobs.length})`);
			printTable(result.jobs);
		} else {
			console.log(JSON.stringify(result, null, 2));
		}
	} catch (err) {
		exit(`Search failed: ${err instanceof Error ? err.message : err}`);
	}
}

if (import.meta.main) {
	const cli = meow(
		`
Usage
  $ seek-api <command> ...

Commands
  search <keywords...>    Search jobs (JSON search API)
  detail <id|url>         Full job description (GraphQL)

Examples
  $ seek-api search typescript --where "New South Wales" --sr 170000- --wt full-time
  $ seek-api detail 93933486
  $ seek-api search --help
  $ seek-api detail --help
		`.trimStart(),
		{
			importMeta: import.meta,
			commands: ['search', 'detail'],
			flags: {
				help: { type: 'boolean', shortFlag: 'h', default: false }
			}
		}
	);

	if (!cli.command || cli.flags.help) cli.showHelp(0);

	if (cli.command === 'detail') await runDetail(cli.input);
	else if (cli.command === 'search') await runSearch(cli.input);
}
