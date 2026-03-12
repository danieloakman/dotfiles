import meow from 'meow';
import { launchBrowser } from './utils/browser';
import { AUTH_FILE } from './utils/env';
import { chromium } from 'playwright';

if (import.meta.main) {
	const { flags } = meow(
		`
    Usage:
    $ remote-chromium [options]

    Options:
    --headless  Run the browser in headless mode. Default: false
    --port      The port to run the remote debugging server on. Default: 9222
  `,
		{
			importMeta: import.meta,
			flags: {
				headless: {
					type: 'boolean',
					default: false
				},
				port: {
					type: 'number',
					default: 9222
				}
			}
		}
	);

	const server = await chromium.launchServer({
		port: flags.port,
		headless: flags.headless,
		host: '0.0.0.0'
		// args: [
		// 	`--remote-debugging-port=${flags.port}`
		// 	// '--remote-debugging-address=0.0.0.0'
		// ]
	});
	const endpoint = server.wsEndpoint();
	console.log(`Chromium server started on ${endpoint}`);
	// const browser = await launchBrowser({
	// 	headless: flags.headless,
	// 	args: [
	// 		`--remote-debugging-port=${flags.port}`,
	// 		'--remote-debugging-address=0.0.0.0'
	// 	]
	// });
	// const context = await browser.newContext({ storageState: DEFAULT_AUTH_FILE });
	// const page = await context.newPage();
	// await page.goto('https://www.seek.com.au/');
	// console.log(
	// 	`Browser launched on remote debugging port ${flags.port}, you can connect to it with the following URL: http://localhost:${flags.port}`
	// );
}
