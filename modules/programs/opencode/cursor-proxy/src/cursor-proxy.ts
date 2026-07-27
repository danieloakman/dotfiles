import { execSync, spawn } from "node:child_process";
import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import { proxyError, proxyLog } from "./logging.js";
import {
  ContentHold,
  joinFragments,
  shouldHoldContent,
  type StreamOut,
} from "./stream-order.js";
import type { ChatMessage, ContentPart, StreamEvent } from "./types.js";

const PORT = parseInt(process.env.PORT || "32124", 10);
const CURSOR_BIN = process.env.CURSOR_AGENT_BIN || "cursor-agent";
// Fallback only. The proxy is a long-lived singleton shared across opencode
// instances, so the real workspace is resolved per request from the
// `x-cursor-workspace` header (see resolveWorkspace). Baking a single workspace
// here caused every request to use whichever directory the proxy first started in.
const DEFAULT_WORKSPACE = process.env.CURSOR_WORKSPACE || process.cwd();

process.on("uncaughtException", (err) => {
  proxyError("uncaughtException:", err.stack || err.message || err);
  process.exit(1);
});

process.on("unhandledRejection", (reason) => {
  proxyError(
    "unhandledRejection:",
    reason instanceof Error ? reason.stack || reason.message : reason
  );
  process.exit(1);
});

proxyLog(
  `start pid=${process.pid} port=${PORT} cursor=${CURSOR_BIN} default_workspace=${DEFAULT_WORKSPACE}`
);

function resolveWorkspace(req: http.IncomingMessage): string {
  const header = req.headers["x-cursor-workspace"];
  const raw = Array.isArray(header) ? header[0] : header;
  if (raw) {
    try {
      const decoded = decodeURIComponent(raw);
      if (
        path.isAbsolute(decoded) &&
        fs.existsSync(decoded) &&
        fs.statSync(decoded).isDirectory()
      ) {
        return decoded;
      }
      proxyError(`ignoring invalid x-cursor-workspace header: ${decoded}`);
    } catch {
      proxyError(`ignoring malformed x-cursor-workspace header: ${raw}`);
    }
  }
  return DEFAULT_WORKSPACE;
}

function isImageMime(mime: string | undefined): boolean {
  return typeof mime === "string" && mime.startsWith("image/");
}

function writeImagePart(part: ContentPart, tmpDir: string, idx: number): string | null {
  fs.mkdirSync(tmpDir, { recursive: true });

  if (part.type === "file") {
    const mime = part.mime || part.mediaType || part.mimeType;
    if (!isImageMime(mime)) return null;
    if (typeof part.data === "string") {
      const ext = (mime!.split("/")[1] || "png").replace("jpeg", "jpg");
      const file = path.join(tmpDir, `image-${idx}.${ext}`);
      fs.writeFileSync(file, Buffer.from(part.data, "base64"));
      return file;
    }
    const fileUrl = part.url || part.uri || part.path || part.filename;
    if (typeof fileUrl === "string") {
      if (fileUrl.startsWith("file://")) return decodeURI(fileUrl.slice(7));
      if (fileUrl.startsWith("/")) return fileUrl;
    }
    return null;
  }

  if (part.type === "image_url" && part.image_url?.url) {
    const url = part.image_url.url;
    if (url.startsWith("data:")) {
      const match = url.match(/^data:([^;]+);base64,(.+)$/s);
      if (!match) return null;
      const ext = (match[1].split("/")[1] || "png").replace("jpeg", "jpg");
      const file = path.join(tmpDir, `image-${idx}.${ext}`);
      fs.writeFileSync(file, Buffer.from(match[2], "base64"));
      return file;
    }
    if (url.startsWith("file://")) return decodeURI(url.slice(7));
    if (url.startsWith("/")) return url;
    return null;
  }

  if (part.type === "image" && part.image) {
    const img = part.image;
    if (img.url?.startsWith("data:")) {
      return writeImagePart({ type: "image_url", image_url: { url: img.url } }, tmpDir, idx);
    }
    if (typeof img.data === "string" && img.media_type) {
      const ext = (img.media_type.split("/")[1] || "png").replace("jpeg", "jpg");
      const file = path.join(tmpDir, `image-${idx}.${ext}`);
      fs.writeFileSync(file, Buffer.from(img.data, "base64"));
      return file;
    }
  }

  return null;
}

function collectImagePaths(messages: ChatMessage[], workspace: string): string[] {
  const tmpDir = path.join(workspace, ".cursor-proxy-images", String(process.pid));
  const paths: string[] = [];
  let idx = 0;
  for (const m of messages) {
    if (!Array.isArray(m.content)) continue;
    for (const part of m.content) {
      const file = writeImagePart(part, tmpDir, idx++);
      if (file) paths.push(file);
    }
  }
  return paths;
}

function messageText(content: ChatMessage["content"]): string {
  if (typeof content === "string") return content.trim();
  if (!Array.isArray(content)) return "";
  return content
    .filter((p) => p && p.type === "text")
    .map((p) => p.text || "")
    .join("\n")
    .trim();
}

function appendImagePaths(lines: string[], imagePaths: string[]): void {
  if (imagePaths.length) {
    lines.push(
      `USER: Attached images (read and analyze these file paths):\n${imagePaths.join("\n")}`
    );
  }
}

function buildPrompt(
  messages: ChatMessage[],
  imagePaths = collectImagePaths(messages, DEFAULT_WORKSPACE)
): string {
  const lines: string[] = [];
  for (const m of messages) {
    const role = m.role || "user";
    const text = messageText(m.content);
    if (text) lines.push(`${role.toUpperCase()}: ${text}`);
  }

  appendImagePaths(lines, imagePaths);

  const last = messages[messages.length - 1];
  const hasUnresolvedToolCalls =
    last && last.role === "assistant" && Array.isArray(last.tool_calls) && last.tool_calls.length > 0;

  let prompt = lines.join("\n\n");
  if (hasUnresolvedToolCalls) {
    const tcNames = last.tool_calls!.map((tc) => tc?.function?.name || "?").join(", ");
    prompt += `\n\n(You called tools: ${tcNames}. The caller will provide results.)`;
  }
  return prompt || "Hello";
}

function buildPromptWithToolResults(
  messages: ChatMessage[],
  imagePaths = collectImagePaths(messages, DEFAULT_WORKSPACE)
): string {
  const lines: string[] = [];
  for (const m of messages) {
    const role = m.role || "user";

    if (role === "tool") {
      const id = m.tool_call_id || "?";
      const body = typeof m.content === "string" ? m.content : JSON.stringify(m.content ?? "");
      lines.push(`TOOL_RESULT(${id}): ${body}`);
      continue;
    }

    if (role === "assistant" && Array.isArray(m.tool_calls) && m.tool_calls.length > 0) {
      const tcs = m.tool_calls
        .map(
          (tc) =>
            `tool_call(${tc.id || "?"}, ${tc.function?.name || "?"}, ${tc.function?.arguments || "{}"})`
        )
        .join("; ");
      const text = typeof m.content === "string" ? m.content : "";
      lines.push(`ASSISTANT: ${text}${text ? " " : ""}[${tcs}]`);
      continue;
    }

    const text = messageText(m.content);
    if (text) lines.push(`${role.toUpperCase()}: ${text}`);
  }

  appendImagePaths(lines, imagePaths);

  const hasToolResults = messages.some((m) => m.role === "tool");
  let prompt = lines.join("\n\n");
  if (hasToolResults) {
    prompt += "\n\nThe above tool calls have been executed. Continue based on these results.";
  }
  return prompt || "Hello";
}

function stripModelPrefix(model: unknown): string {
  return String(model || "auto").replace(/^cursor-acp\//, "") || "auto";
}

function formatSseChunk(
  id: string,
  created: number,
  model: string,
  delta: Record<string, string>
): string {
  return (
    "data: " +
    JSON.stringify({
      id,
      object: "chat.completion.chunk",
      created,
      model,
      choices: [{ index: 0, delta, finish_reason: null }],
    }) +
    "\n\n"
  );
}

function formatSseFinal(
  id: string,
  created: number,
  model: string,
  content: string | undefined
): string {
  return (
    "data: " +
    JSON.stringify({
      id,
      object: "chat.completion.chunk",
      created,
      model,
      choices: [{ index: 0, delta: content ? { content } : {}, finish_reason: "stop" }],
    }) +
    "\n\ndata: [DONE]\n\n"
  );
}

function parseLine(line: string): StreamEvent | null {
  try {
    const trimmed = line.trim();
    if (!trimmed) return null;
    const obj = JSON.parse(trimmed) as unknown;
    if (!obj || typeof obj !== "object" || Array.isArray(obj)) return null;
    return obj as StreamEvent;
  } catch {
    return null;
  }
}

function isAssistantStreamDelta(ev: StreamEvent): boolean {
  return typeof ev.timestamp_ms === "number" && !ev.model_call_id;
}

function assistantFragment(ev: StreamEvent): string {
  if (!Array.isArray(ev.message?.content)) return "";
  return ev.message.content
    .filter((p) => p?.type === "text" && p.text)
    .map((p) => p.text!)
    .join("");
}

type Usage = NonNullable<StreamEvent["usage"]>;

const server = http.createServer(async (req, res) => {
  res.on("error", () => {});
  const url = new URL(req.url || "/", `http://${req.headers.host}`);

  if (url.pathname === "/health") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ ok: true, workspace: DEFAULT_WORKSPACE }));
    return;
  }

  if (url.pathname === "/v1/models" || url.pathname === "/models") {
    try {
      const output = execSync(`${CURSOR_BIN} models`, { encoding: "utf8", timeout: 10000 });
      const models: Array<{
        id: string;
        object: string;
        created: number;
        owned_by: string;
      }> = [];
      for (const line of output.split("\n")) {
        const m = line.match(/^([a-z0-9.-]+)\s+-\s+(.+?)(?:\s+\((current|default)\))*\s*$/i);
        if (m) {
          models.push({
            id: m[1],
            object: "model",
            created: Math.floor(Date.now() / 1000),
            owned_by: "cursor",
          });
        }
      }
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ object: "list", data: models }));
    } catch (e) {
      console.error(`[${new Date().toISOString()}] model list failed: ${e}`);
      res.writeHead(500, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: String(e) }));
    }
    return;
  }

  if (url.pathname !== "/v1/chat/completions" && url.pathname !== "/chat/completions") {
    console.error(`[${new Date().toISOString()}] 404: ${url.pathname}`);
    res.writeHead(404, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ error: "Not found" }));
    return;
  }

  let body = "";
  for await (const chunk of req) body += chunk;
  let parsed: {
    messages?: ChatMessage[];
    stream?: boolean;
    model?: string;
  };
  try {
    parsed = JSON.parse(body || "{}");
  } catch {
    console.error(
      `[${new Date().toISOString()}] 400: invalid JSON from ${req.socket?.remoteAddress}`
    );
    res.writeHead(400, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ error: "Invalid JSON" }));
    return;
  }

  const messages = Array.isArray(parsed.messages) ? parsed.messages : [];
  const stream = parsed.stream === true;
  const model = stripModelPrefix(parsed.model);
  const workspace = resolveWorkspace(req);
  const includeThinking = process.env.CURSOR_PROXY_INCLUDE_THINKING !== "false";
  const useStreamPartial = process.env.CURSOR_PROXY_PARTIAL !== "false";
  const imagePaths = collectImagePaths(messages, workspace);
  const hasToolResults = messages.some((m) => m.role === "tool");
  const prompt = hasToolResults
    ? buildPromptWithToolResults(messages, imagePaths)
    : buildPrompt(messages, imagePaths);

  proxyLog(
    `[cursor-proxy] ${req.method} /v1/chat/completions model=${model} msgs=${messages.length} stream=${stream} images=${imagePaths.length} prompt=${prompt.length}ch workspace=${workspace}`
  );

  const id = `cursor-${Date.now()}`;
  const created = Math.floor(Date.now() / 1000);
  const modelId = `cursor-acp/${model}`;

  const args = [
    "--print",
    "--output-format",
    "stream-json",
    "--force",
    "--workspace",
    workspace,
    "--model",
    model,
  ];
  if (useStreamPartial) args.push("--stream-partial-output");

  const child = spawn(CURSOR_BIN, args, {
    stdio: ["pipe", "pipe", "pipe"],
    cwd: workspace,
    env: { ...process.env },
  });

  const REQUEST_TIMEOUT = parseInt(process.env.CURSOR_PROXY_TIMEOUT || "", 10) || 300000;
  const timeout = setTimeout(() => {
    child.kill("SIGKILL");
    if (!res.writableEnded) {
      if (stream) {
        res.write(formatSseFinal(id, created, modelId, ""));
        res.end();
      } else {
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(
          JSON.stringify({
            id,
            object: "chat.completion",
            created,
            model: modelId,
            choices: [
              {
                index: 0,
                message: { role: "assistant", content: "Request timed out. Please try again." },
                finish_reason: "stop",
              },
            ],
          })
        );
      }
    }
  }, REQUEST_TIMEOUT);

  child.stdin.write(prompt);
  child.stdin.end();

  let usage: Usage | null = null;
  let terminalResult = "";
  let streamedContent = false;
  let streamedReasoning = false;
  let collectedReasoning = "";
  let collectedContent = "";

  const contentHold = new ContentHold({
    enabled:
      stream && useStreamPartial && includeThinking && shouldHoldContent(model),
  });

  const emitContentDelta = (text: string) => {
    if (!stream || res.writableEnded || !text) return;
    res.write(formatSseChunk(id, created, modelId, { content: text }));
    streamedContent = true;
  };

  const emitReasoningDelta = (text: string) => {
    if (!stream || res.writableEnded || !text || !includeThinking) return;
    res.write(formatSseChunk(id, created, modelId, { reasoning_content: text }));
    streamedReasoning = true;
  };

  const emitHeld = (outs: StreamOut[]) => {
    for (const o of outs) {
      if (o.kind === "reasoning") emitReasoningDelta(o.text);
      else emitContentDelta(o.text);
    }
  };

  const parseOutputLine = (line: string) => {
    const ev = parseLine(line);
    if (!ev) return;

    if (ev.type === "thinking" && includeThinking) {
      if (ev.subtype === "delta" && ev.text) {
        collectedReasoning += ev.text;
        if (useStreamPartial) emitHeld(contentHold.onThinkingDelta(ev.text));
        return;
      }
      if (ev.subtype === "completed") {
        if (useStreamPartial) emitHeld(contentHold.onThinkingCompleted());
        return;
      }
    }

    if (ev.type === "result") {
      if (ev.usage) usage = ev.usage;
      if (typeof ev.result === "string" && ev.result) {
        terminalResult = ev.result;
        if (stream && !useStreamPartial) emitContentDelta(ev.result);
      }
      return;
    }

    if (ev.type === "assistant") {
      if (useStreamPartial && !isAssistantStreamDelta(ev)) return;
      const fragment = assistantFragment(ev);
      if (!fragment) return;
      collectedContent = joinFragments(collectedContent, fragment);
      if (stream && useStreamPartial) emitHeld(contentHold.onContent(fragment));
      return;
    }
  };

  const formatUsage = (u: Usage) => ({
    prompt_tokens: (u.inputTokens || 0) + (u.cacheReadTokens || 0) + (u.cacheWriteTokens || 0),
    completion_tokens: u.outputTokens || 0,
    total_tokens:
      (u.inputTokens || 0) +
      (u.outputTokens || 0) +
      (u.cacheReadTokens || 0) +
      (u.cacheWriteTokens || 0),
    ...(u.reasoningTokens
      ? { completion_tokens_details: { reasoning_tokens: u.reasoningTokens } }
      : {}),
    ...(u.cacheReadTokens
      ? { prompt_tokens_details: { cached_tokens: u.cacheReadTokens } }
      : {}),
  });

  const buildFinalResponse = (content: string, reasoning = "") => ({
    id,
    object: "chat.completion",
    created,
    model: modelId,
    choices: [
      {
        index: 0,
        message: {
          role: "assistant",
          content: content || "No response",
          ...(reasoning ? { reasoning_content: reasoning } : {}),
        },
        finish_reason: "stop",
      },
    ],
    usage: usage ? formatUsage(usage) : undefined,
  });

  const buildSseUsageChunk = () => {
    if (!usage) return "";
    return (
      "data: " +
      JSON.stringify({
        id,
        object: "chat.completion.chunk",
        created,
        model: modelId,
        choices: [],
        usage: formatUsage(usage),
      }) +
      "\n\n"
    );
  };

  if (!stream) {
    const stdoutChunks: Buffer[] = [];
    const stderrChunks: Buffer[] = [];
    child.stdout.on("data", (c: Buffer) => stdoutChunks.push(c));
    child.stderr.on("data", (c: Buffer) => stderrChunks.push(c));
    child.on("close", (code) => {
      clearTimeout(timeout);
      const stdout = Buffer.concat(stdoutChunks).toString().trim();
      const stderr = Buffer.concat(stderrChunks).toString().trim();

      collectedReasoning = "";
      collectedContent = "";
      for (const line of stdout.split("\n")) parseOutputLine(line);

      let content = collectedContent || terminalResult;
      const reasoning = collectedReasoning;
      if (code !== 0 || (stderr && !content)) {
        content = `Error: ${stderr || `cursor-agent exited with code ${code}`}`;
      }

      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify(buildFinalResponse(content, reasoning)));
    });
    return;
  }

  res.writeHead(200, {
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache",
    Connection: "keep-alive",
  });

  let buffer = "";

  child.stdout.on("data", (chunk: Buffer) => {
    buffer += chunk.toString();
    const lines = buffer.split("\n");
    buffer = lines.pop() || "";
    for (const line of lines) parseOutputLine(line);
  });

  child.on("close", (code) => {
    clearTimeout(timeout);
    if (buffer) parseOutputLine(buffer);
    if (!res.writableEnded) {
      emitHeld(contentHold.finish());
      const finalText = terminalResult || collectedContent;
      if (!streamedContent && finalText) {
        emitContentDelta(finalText);
      }
      const usageChunk = buildSseUsageChunk();
      if (usageChunk) res.write(usageChunk);
      res.write(formatSseFinal(id, created, modelId, undefined));
      res.end();
    }
    proxyLog(
      `[cursor-proxy] stream done id=${id} model=${model} code=${code} content=${streamedContent} reasoning=${streamedReasoning} chars=${(collectedContent || terminalResult).length}`
    );
  });

  child.on("error", (err) => {
    clearTimeout(timeout);
    console.error(
      `[${new Date().toISOString()}] spawn error id=${id} model=${model}: ${err.message}`
    );
    if (!res.writableEnded) {
      res.write(formatSseChunk(id, created, modelId, { content: `Error: ${err.message}` }));
      const usageChunk = buildSseUsageChunk();
      if (usageChunk) res.write(usageChunk);
      res.write(formatSseFinal(id, created, modelId, ""));
      res.end();
    }
  });
});

server.on("error", (err) => {
  if ((err as NodeJS.ErrnoException).code === "EADDRINUSE") {
    proxyLog(`port ${PORT} already in use, assuming another instance is running`);
    process.exit(0);
  }
  proxyError(`server error: ${err.message}`);
  process.exit(1);
});

server.listen(PORT, "127.0.0.1", () => {
  proxyLog(`[cursor-proxy] listening on http://127.0.0.1:${PORT}`);
});
