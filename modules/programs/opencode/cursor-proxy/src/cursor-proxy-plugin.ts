import { type ChildProcess, spawn } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { proxyError, proxyLog } from "./logging.js";
import type { OpenCodeConfig } from "./types.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
const PROXY_SCRIPT =
  process.env.CURSOR_PROXY_SCRIPT || join(__dirname, "cursor-proxy.cjs");

let child: ChildProcess | null = null;

async function proxyReachable(port: number): Promise<boolean> {
  try {
    const res = await fetch(`http://127.0.0.1:${port}/v1/models`, {
      signal: AbortSignal.timeout(2000),
    });
    return res.ok;
  } catch {
    return false;
  }
}

const visionModalities = { input: ["text", "image"], output: ["text"] } as const;

function cursorModel(name: string) {
  return {
    name,
    limit: { context: 200000, input: 200000, output: 64000 },
    modalities: visionModalities,
  };
}

function pluginApi(port: number) {
  return {
    config: (cfg: OpenCodeConfig) => {
      cfg.provider = cfg.provider || {};
      cfg.provider["cursor-acp"] = {
        name: "Cursor ACP",
        npm: "@ai-sdk/openai-compatible",
        options: { baseURL: `http://127.0.0.1:${port}/v1` },
        models: {
          auto: cursorModel("Auto"),
          "composer-2.5": cursorModel("Composer 2.5"),
          "claude-4.6-opus-high": cursorModel("Opus 4.6 High"),
          "claude-4.6-opus-max": cursorModel("Opus 4.6 Max"),
          "claude-4.6-opus-max-thinking": cursorModel("Opus 4.6 Max Thinking"),
          "claude-4.6-sonnet-medium": cursorModel("Sonnet 4.6 Medium"),
          "claude-4.6-sonnet-medium-thinking": cursorModel("Sonnet 4.6 Medium Thinking"),
          "gpt-5.5-none": cursorModel("GPT 5.5 None"),
          "gpt-5.5-low": cursorModel("GPT 5.5 Low"),
          "gpt-5.5-medium": cursorModel("GPT 5.5 Medium"),
          "gpt-5.5-high": cursorModel("GPT 5.5 High"),
          "gpt-5.5-extra-high": cursorModel("GPT 5.5 Extra High"),
        },
      };
    },
  };
}

export default async function cursorProxyPlugin() {
  const port = parseInt(process.env.CURSOR_PROXY_PORT || "32124", 10);
  const cursorBin = process.env.CURSOR_AGENT_BIN || "cursor-agent";
  const workspace = process.env.CURSOR_WORKSPACE || process.cwd();
  const nodeBin = process.env.NODE_BIN || "node";

  if (await proxyReachable(port)) {
    proxyLog(`using existing proxy on port ${port}`);
    return pluginApi(port);
  }

  proxyLog(`spawning ${nodeBin} ${PROXY_SCRIPT}`);

  child = spawn(nodeBin, [PROXY_SCRIPT], {
    env: {
      ...process.env,
      PORT: String(port),
      CURSOR_AGENT_BIN: cursorBin,
      CURSOR_WORKSPACE: workspace,
      CURSOR_PROXY_QUIET: process.env.CURSOR_PROXY_QUIET ?? "true",
    },
    stdio: ["ignore", "ignore", "pipe"],
  });

  let stderrBuf = "";

  child.stderr?.on("data", (chunk: Buffer) => {
    const text = chunk.toString();
    stderrBuf += text;
    if (stderrBuf.length > 16_000) stderrBuf = stderrBuf.slice(-16_000);
    for (const line of text.split("\n")) {
      if (line.trim()) proxyError(line);
    }
  });

  child.on("error", (err) => {
    proxyError(`Failed to start: ${err.message}`);
  });

  child.on("exit", async (code, signal) => {
    const up = await proxyReachable(port);
    if (code !== 0 && signal === null && !up) {
      const tail = stderrBuf.trim();
      proxyError(`Exited with code ${code}`);
      if (tail) proxyError(tail);
    }
    child = null;
  });

  const kill = () => {
    if (child) {
      child.kill("SIGTERM");
      setTimeout(() => child?.kill("SIGKILL"), 3000);
      child = null;
    }
  };

  process.on("exit", kill);
  process.on("SIGINT", kill);
  process.on("SIGTERM", kill);

  for (let i = 0; i < 30; i++) {
    if (await proxyReachable(port)) break;
    await new Promise((r) => setTimeout(r, 100));
  }

  if (!(await proxyReachable(port))) {
    const tail = stderrBuf.trim();
    proxyError(`Proxy not listening on port ${port} after startup`);
    if (tail) proxyError(tail);
  }

  return pluginApi(port);
}
