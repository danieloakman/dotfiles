import { z, type ZodType } from 'zod';

const GWS = process.env.GWS_BIN ?? 'gws';

const gwsErrorSchema = z.object({
	error: z.object({
		code: z.number(),
		message: z.string(),
		reason: z.string().optional()
	})
});

export async function gwsJson<S extends ZodType>(args: string[], schema: S): Promise<z.infer<S>> {
	const proc = Bun.spawn([GWS, ...args], { stdout: 'pipe', stderr: 'pipe' });
	const [stdout, stderr, exitCode] = await Promise.all([
		new Response(proc.stdout).text(),
		new Response(proc.stderr).text(),
		proc.exited
	]);
	const data: unknown = JSON.parse(stdout || '{}');
	const apiError = gwsErrorSchema.safeParse(data);
	if (exitCode !== 0 || apiError.success) {
		const message = apiError.success ? apiError.data.error.message : stderr.trim();
		throw new Error(message || `gws ${args.join(' ')} failed (${exitCode})`);
	}
	return schema.parse(data);
}
