import { emailClient } from "./utils/email";

if (import.meta.main) {
	emailClient
		.listEmails({ query: 'in:inbox', max: 5 })
		.then(console.log)
		.catch(console.error);
}
