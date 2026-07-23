import * as esbuild from "esbuild";
import { spawnSync } from "node:child_process";
import { unlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const outfile = join(tmpdir(), `cursor-proxy-stream-order-test-${process.pid}.cjs`);

await esbuild.build({
  entryPoints: ["src/stream-order.test.ts"],
  bundle: true,
  platform: "node",
  target: "node20",
  format: "cjs",
  outfile,
  logLevel: "silent",
});

const result = spawnSync(process.execPath, [outfile], { stdio: "inherit" });
try {
  unlinkSync(outfile);
} catch {
  // ignore cleanup failures
}
process.exit(result.status ?? 1);
