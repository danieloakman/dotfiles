import * as esbuild from "esbuild";

const shared = {
  bundle: true,
  platform: "node",
  target: "node20",
  packages: "external",
  logLevel: "info",
};

await esbuild.build({
  ...shared,
  entryPoints: ["src/cursor-proxy.ts"],
  format: "cjs",
  outfile: "dist/cursor-proxy.cjs",
  banner: { js: "#!/usr/bin/env node" },
});

await esbuild.build({
  ...shared,
  entryPoints: ["src/cursor-proxy-plugin.ts"],
  format: "esm",
  outfile: "dist/cursor-proxy-plugin.mjs",
});
