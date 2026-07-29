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

const CONTEXT_1M = 1_000_000;
const CONTEXT_500K = 500_000;
const CONTEXT_200K = 200_000;
const DEFAULT_OUTPUT = 64_000;

const MODEL_CONTEXT: Record<string, number> = {
  auto: CONTEXT_500K,
  "composer-2.5": CONTEXT_200K,
  "claude-4.6-opus-high": CONTEXT_1M,
  "claude-4.6-opus-max": CONTEXT_1M,
  "claude-4.6-opus-max-thinking": CONTEXT_1M,
  "claude-4.6-sonnet-medium": CONTEXT_1M,
  "claude-4.6-sonnet-medium-thinking": CONTEXT_1M,
  "gpt-5.5-none": CONTEXT_1M,
  "gpt-5.5-low": CONTEXT_1M,
  "gpt-5.5-medium": CONTEXT_1M,
  "gpt-5.5-high": CONTEXT_1M,
  "gpt-5.5-extra-high": CONTEXT_1M,
};

function isReasoningModel(name: string, modelId: string): boolean {
  const haystack = `${modelId} ${name}`.toLowerCase();
  return haystack.includes("thinking");
}

function cursorModel(name: string, modelId: string) {
  const base = {
    name,
    modalities: visionModalities,
    ...(isReasoningModel(name, modelId)
      ? {
          reasoning: true,
          interleaved: { field: "reasoning_content" as const },
        }
      : {}),
  };
  const context = MODEL_CONTEXT[modelId] ?? CONTEXT_200K;
  return {
    ...base,
    limit: { context, input: context, output: DEFAULT_OUTPUT },
  };
}

function pluginApi(port: number, workspace: string) {
  return {
    config: (cfg: OpenCodeConfig) => {
      cfg.provider = cfg.provider || {};
      cfg.provider["cursor-acp"] = {
        name: "Cursor ACP",
        npm: "@ai-sdk/openai-compatible",
        options: {
          baseURL: `http://127.0.0.1:${port}/v1`,
          // Per-instance workspace for the shared long-lived proxy.
          headers: { "x-cursor-workspace": encodeURIComponent(workspace) },
        },
        models: {
          auto: cursorModel("Cursor - Auto", "auto"),
          "composer-2.5": cursorModel("Composer 2.5", "composer-2.5"),
          "claude-4.6-opus-high": cursorModel("Opus 4.6 High", "claude-4.6-opus-high"),
          "claude-4.6-opus-max": cursorModel("Opus 4.6 Max", "claude-4.6-opus-max"),
          "claude-4.6-opus-max-thinking": cursorModel(
            "Opus 4.6 Max Thinking",
            "claude-4.6-opus-max-thinking",
          ),
          "claude-4.6-sonnet-medium": cursorModel(
            "Sonnet 4.6 Medium",
            "claude-4.6-sonnet-medium",
          ),
          "claude-4.6-sonnet-medium-thinking": cursorModel(
            "Sonnet 4.6 Medium Thinking",
            "claude-4.6-sonnet-medium-thinking",
          ),
          "gpt-5.5-none": cursorModel("GPT 5.5 None", "gpt-5.5-none"),
          "gpt-5.5-low": cursorModel("GPT 5.5 Low", "gpt-5.5-low"),
          "gpt-5.5-medium": cursorModel("GPT 5.5 Medium", "gpt-5.5-medium"),
          "gpt-5.5-high": cursorModel("GPT 5.5 High", "gpt-5.5-high"),
          "gpt-5.5-extra-high": cursorModel("GPT 5.5 Extra High", "gpt-5.5-extra-high"),
        },
      };
    },
  };
}

export default async function cursorProxyPlugin(input?: { directory?: string }) {
  const port = parseInt(process.env.CURSOR_PROXY_PORT || "32124", 10);
  const cursorBin = process.env.CURSOR_AGENT_BIN || "cursor-agent";
  const workspace =
    input?.directory || process.env.CURSOR_WORKSPACE || process.cwd();
  const nodeBin = process.env.NODE_BIN || "node";

  if (await proxyReachable(port)) {
    proxyLog(`using existing proxy on port ${port}`);
    return pluginApi(port, workspace);
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

  return pluginApi(port, workspace);
}
