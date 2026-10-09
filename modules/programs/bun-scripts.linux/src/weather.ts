#! bun
import meow from 'meow';
import { z } from 'zod';

import { exit, helpFlag } from './utils/cli';

const DEFAULT_DAYS = 7;
const DEFAULT_HOURLY_DAYS = 2;
const GEOCODE_URL = 'https://geocoding-api.open-meteo.com/v1/search';
const FORECAST_URL = 'https://api.open-meteo.com/v1/forecast';

const geocodeResultSchema = z.object({
	name: z.string(),
	latitude: z.number(),
	longitude: z.number(),
	timezone: z.string().optional(),
	country: z.string().optional(),
	admin1: z.string().optional()
});

const geocodeResponseSchema = z.object({
	results: z.array(geocodeResultSchema).optional()
});

const dailyForecastSchema = z.object({
	latitude: z.number(),
	longitude: z.number(),
	timezone: z.string(),
	daily_units: z.object({
		temperature_2m_max: z.string(),
		temperature_2m_min: z.string(),
		wind_speed_10m_max: z.string(),
		precipitation_sum: z.string()
	}),
	daily: z.object({
		time: z.array(z.string()),
		temperature_2m_max: z.array(z.number().nullable()),
		temperature_2m_min: z.array(z.number().nullable()),
		wind_speed_10m_max: z.array(z.number().nullable()),
		precipitation_sum: z.array(z.number().nullable())
	})
});

const hourlyForecastSchema = z.object({
	latitude: z.number(),
	longitude: z.number(),
	timezone: z.string(),
	hourly_units: z.object({
		temperature_2m: z.string(),
		precipitation: z.string(),
		wind_speed_10m: z.string()
	}),
	hourly: z.object({
		time: z.array(z.string()),
		temperature_2m: z.array(z.number().nullable()),
		precipitation: z.array(z.number().nullable()),
		wind_speed_10m: z.array(z.number().nullable())
	})
});

type GeocodeResult = z.infer<typeof geocodeResultSchema>;
type DailyForecast = z.infer<typeof dailyForecastSchema>;
type HourlyForecast = z.infer<typeof hourlyForecastSchema>;

type DayRow = {
	date: string;
	tempMaxC: number | null;
	tempMinC: number | null;
	windMaxKmh: number | null;
	precipMm: number | null;
};

type HourRow = {
	time: string;
	tempC: number | null;
	windKmh: number | null;
	precipMm: number | null;
};

async function fetchJson(url: string): Promise<unknown> {
	const res = await fetch(url);
	if (!res.ok) exit(`Request failed (${res.status}): ${url}`);
	return res.json();
}

async function geocode(name: string): Promise<GeocodeResult> {
	const url = new URL(GEOCODE_URL);
	url.searchParams.set('name', name);
	url.searchParams.set('count', '1');
	url.searchParams.set('language', 'en');

	const parsed = geocodeResponseSchema.safeParse(await fetchJson(url.toString()));
	if (!parsed.success) exit(`Unexpected geocode response: ${parsed.error.message}`);
	const hit = parsed.data.results?.[0];
	if (!hit) exit(`No location found for "${name}"`);
	return hit;
}

function forecastUrl(
	latitude: number,
	longitude: number,
	days: number,
	timezone: string | undefined,
	mode: 'daily' | 'hourly'
): string {
	const url = new URL(FORECAST_URL);
	url.searchParams.set('latitude', String(latitude));
	url.searchParams.set('longitude', String(longitude));
	url.searchParams.set('timezone', timezone ?? 'auto');
	url.searchParams.set('forecast_days', String(days));
	if (mode === 'hourly') {
		url.searchParams.set('hourly', 'temperature_2m,precipitation,wind_speed_10m');
	} else {
		url.searchParams.set(
			'daily',
			'temperature_2m_max,temperature_2m_min,wind_speed_10m_max,precipitation_sum'
		);
	}
	return url.toString();
}

async function fetchDaily(
	latitude: number,
	longitude: number,
	days: number,
	timezone?: string
): Promise<DailyForecast> {
	const parsed = dailyForecastSchema.safeParse(
		await fetchJson(forecastUrl(latitude, longitude, days, timezone, 'daily'))
	);
	if (!parsed.success) exit(`Unexpected forecast response: ${parsed.error.message}`);
	return parsed.data;
}

async function fetchHourly(
	latitude: number,
	longitude: number,
	days: number,
	timezone?: string
): Promise<HourlyForecast> {
	const parsed = hourlyForecastSchema.safeParse(
		await fetchJson(forecastUrl(latitude, longitude, days, timezone, 'hourly'))
	);
	if (!parsed.success) exit(`Unexpected forecast response: ${parsed.error.message}`);
	return parsed.data;
}

function locationLabel(place: GeocodeResult): string {
	return [place.name, place.admin1, place.country].filter(Boolean).join(', ');
}

function dayRows(data: DailyForecast): DayRow[] {
	const { daily } = data;
	return daily.time.map((date, i) => ({
		date,
		tempMaxC: daily.temperature_2m_max[i] ?? null,
		tempMinC: daily.temperature_2m_min[i] ?? null,
		windMaxKmh: daily.wind_speed_10m_max[i] ?? null,
		precipMm: daily.precipitation_sum[i] ?? null
	}));
}

function hourRows(data: HourlyForecast): HourRow[] {
	const { hourly } = data;
	return hourly.time.map((time, i) => ({
		time,
		tempC: hourly.temperature_2m[i] ?? null,
		windKmh: hourly.wind_speed_10m[i] ?? null,
		precipMm: hourly.precipitation[i] ?? null
	}));
}

function fmt(n: number | null, digits = 1): string {
	return n == null ? '—' : n.toFixed(digits);
}

function fmtHour(iso: string): string {
	return iso.replace('T', ' ');
}

function printDaily(label: string, data: DailyForecast, rows: DayRow[]): void {
	const units = data.daily_units;
	console.log(label);
	console.log(
		`${data.latitude.toFixed(3)}, ${data.longitude.toFixed(3)} · ${data.timezone} · ${rows.length} day(s)`
	);
	console.log();
	console.log(
		[
			'Date'.padEnd(12),
			`Min(${units.temperature_2m_min})`.padStart(8),
			`Max(${units.temperature_2m_max})`.padStart(8),
			`Wind(${units.wind_speed_10m_max})`.padStart(12),
			`Rain(${units.precipitation_sum})`.padStart(10)
		].join('  ')
	);
	for (const day of rows) {
		console.log(
			[
				day.date.padEnd(12),
				fmt(day.tempMinC).padStart(8),
				fmt(day.tempMaxC).padStart(8),
				fmt(day.windMaxKmh).padStart(12),
				fmt(day.precipMm).padStart(10)
			].join('  ')
		);
	}
}

function printHourly(label: string, data: HourlyForecast, rows: HourRow[]): void {
	const units = data.hourly_units;
	console.log(label);
	console.log(
		`${data.latitude.toFixed(3)}, ${data.longitude.toFixed(3)} · ${data.timezone} · ${rows.length} hour(s)`
	);
	console.log();
	console.log(
		[
			'Time'.padEnd(16),
			`Temp(${units.temperature_2m})`.padStart(9),
			`Wind(${units.wind_speed_10m})`.padStart(12),
			`Rain(${units.precipitation})`.padStart(10)
		].join('  ')
	);
	for (const hour of rows) {
		console.log(
			[
				fmtHour(hour.time).padEnd(16),
				fmt(hour.tempC).padStart(9),
				fmt(hour.windKmh).padStart(12),
				fmt(hour.precipMm).padStart(10)
			].join('  ')
		);
	}
}

function daysFlagPassed(): boolean {
	return process.argv.some((arg) => arg === '-d' || arg === '--days' || arg.startsWith('--days='));
}

if (import.meta.main) {
	const cli = meow(
		`
    Usage:
      $ weather <location>
      $ weather <location> --hourly
      $ weather --lat <-34.42> --lon <150.89>

    Options:
      -h, --help         Show help
      -H, --hourly       Hourly temp / wind / rain (default: daily)
      -d, --days <n>     Forecast days (1–16). Default: ${DEFAULT_DAYS} daily, ${DEFAULT_HOURLY_DAYS} hourly
      --lat <n>          Latitude (use with --lon; skips geocoding)
      --lon <n>          Longitude (use with --lat; skips geocoding)
      --json             Print machine-readable JSON
  `,
		{
			importMeta: import.meta,
			allowUnknownFlags: false,
			flags: {
				...helpFlag,
				hourly: {
					type: 'boolean',
					shortFlag: 'H',
					default: false
				},
				days: {
					type: 'number',
					shortFlag: 'd',
					default: DEFAULT_DAYS
				},
				lat: {
					type: 'number'
				},
				lon: {
					type: 'number'
				},
				json: {
					type: 'boolean',
					default: false
				}
			}
		}
	);

	if (cli.flags.help) cli.showHelp(0);

	const hourly = cli.flags.hourly;
	const days = hourly && !daysFlagPassed() ? DEFAULT_HOURLY_DAYS : cli.flags.days;
	if (!Number.isInteger(days) || days < 1 || days > 16) {
		exit('--days must be an integer from 1 to 16');
	}

	const hasLat = cli.flags.lat !== undefined;
	const hasLon = cli.flags.lon !== undefined;
	if (hasLat !== hasLon) exit('Provide both --lat and --lon, or a location name');

	const locationName = cli.input.join(' ').trim();
	if (!hasLat && !locationName) {
		exit('Provide a location name, or --lat and --lon');
	}
	if (hasLat && locationName) {
		exit('Use either a location name or --lat/--lon, not both');
	}

	let latitude: number;
	let longitude: number;
	let label: string;
	let timezone: string | undefined;

	if (hasLat && hasLon) {
		latitude = cli.flags.lat!;
		longitude = cli.flags.lon!;
		label = `${latitude}, ${longitude}`;
	} else {
		const place = await geocode(locationName);
		latitude = place.latitude;
		longitude = place.longitude;
		timezone = place.timezone;
		label = locationLabel(place);
	}

	if (hourly) {
		const data = await fetchHourly(latitude, longitude, days, timezone);
		const rows = hourRows(data);
		if (cli.flags.json) {
			console.log(
				JSON.stringify(
					{
						location: label,
						latitude: data.latitude,
						longitude: data.longitude,
						timezone: data.timezone,
						resolution: 'hourly',
						units: data.hourly_units,
						hours: rows
					},
					null,
					2
				)
			);
		} else {
			printHourly(label, data, rows);
		}
	} else {
		const data = await fetchDaily(latitude, longitude, days, timezone);
		const rows = dayRows(data);
		if (cli.flags.json) {
			console.log(
				JSON.stringify(
					{
						location: label,
						latitude: data.latitude,
						longitude: data.longitude,
						timezone: data.timezone,
						resolution: 'daily',
						units: data.daily_units,
						days: rows
					},
					null,
					2
				)
			);
		} else {
			printDaily(label, data, rows);
		}
	}
}
