#!/usr/bin/env node
/**
 * cursor-proxy.cjs — OpenAI-compatible proxy for cursor-agent
 *
 * Forked from opencode-cursor-agent-proxy with fixes for OpenCode web/TUI:
 * - Stream from terminal `result` only (assistant lines between tool calls duplicate in OpenCode)
 * - Skip reasoning_content SSE (OpenCode web misparses it)
 * - Send final assistant text in the closing SSE chunk
 * - Quiet logs when CURSOR_PROXY_QUIET=true
 */

const fs = require("fs");
const http = require("http");
const os = require("os");
const path = require("path");
const { spawn } = require("child_process");

const PORT = parseInt(process.env.PORT || "32124", 10);
const CURSOR_BIN = process.env.CURSOR_AGENT_BIN || "cursor-agent";
const WORKSPACE = process.env.CURSOR_WORKSPACE || process.cwd();
const QUIET = process.env.CURSOR_PROXY_QUIET === "true";

function proxyLog(...args) {
  if (!QUIET) console.error("[cursor-proxy]", ...args);
}

function proxyError(...args) {
  console.error("[cursor-proxy]", ...args);
}

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
  `start pid=${process.pid} port=${PORT} cursor=${CURSOR_BIN} workspace=${WORKSPACE}`
);

// ── helpers ────────────────────────────────────────────────────────────────

function isImageMime(mime) {
  return typeof mime === "string" && mime.startsWith("image/");
}

function writeImagePart(part, tmpDir, idx) {
  fs.mkdirSync(tmpDir, { recursive: true });

  if (part.type === "file") {
    const mime = part.mime || part.mediaType || part.mimeType;
    if (!isImageMime(mime)) return null;
    if (typeof part.data === "string") {
      const ext = (mime.split("/")[1] || "png").replace("jpeg", "jpg");
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

function collectImagePaths(messages) {
  const tmpDir = path.join(WORKSPACE, ".cursor-proxy-images", String(process.pid));
  const paths = [];
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

function messageText(content) {
  if (typeof content === "string") return content.trim();
  if (!Array.isArray(content)) return "";
  return content
    .filter((p) => p && p.type === "text")
    .map((p) => p.text || "")
    .join("\n")
    .trim();
}

function appendImagePaths(lines, imagePaths) {
  if (imagePaths.length) {
    lines.push(`USER: Attached images (read and analyze these file paths):\n${imagePaths.join("\n")}`);
  }
}

function buildPrompt(messages, imagePaths = collectImagePaths(messages)) {
  const lines = [];
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
    const tcNames = last.tool_calls.map((tc) => tc?.function?.name || "?").join(", ");
    prompt += `\n\n(You called tools: ${tcNames}. The caller will provide results.)`;
  }
  return prompt || "Hello";
}

function buildPromptWithToolResults(messages, imagePaths = collectImagePaths(messages)) {
  const lines = [];
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
        .map((tc) => `tool_call(${tc.id || "?"}, ${tc.function?.name || "?"}, ${tc.function?.arguments || "{}"})`)
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

function stripModelPrefix(model) {
  return String(model || "auto").replace(/^cursor-acp\//, "") || "auto";
}

function formatSseChunk(id, created, model, delta) {
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

function formatSseFinal(id, created, model, content) {
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

function parseLine(line) {
  try {
    const trimmed = line.trim();
    if (!trimmed) return null;
    const obj = JSON.parse(trimmed);
    if (!obj || typeof obj !== "object" || Array.isArray(obj)) return null;
    return obj;
  } catch {
    return null;
  }
}

class DeltaTracker {
  constructor() {
    this.text = "";
    this.thinking = "";
  }
  nextText(newText) {
    if (!newText || newText === this.text) return "";
    if (newText.startsWith(this.text)) {
      let delta = newText.slice(this.text.length);
      if (this.text && delta.startsWith(this.text)) {
        delta = delta.slice(this.text.length);
      }
      if (!delta) return "";
      this.text = newText;
      return delta;
    }
    this.text = newText;
    return newText;
  }
  nextThinking(newThinking) {
    if (!newThinking || newThinking === this.thinking) return "";
    if (newThinking.startsWith(this.thinking)) {
      let delta = newThinking.slice(this.thinking.length);
      if (this.thinking && delta.startsWith(this.thinking)) {
        delta = delta.slice(this.thinking.length);
      }
      if (!delta) return "";
      this.thinking = newThinking;
      return delta;
    }
    this.thinking = newThinking;
    return newThinking;
  }
}

// ── HTTP server ─────────────────────────────────────────────────────────────

const server = http.createServer(async (req, res) => {
  res.on("error", () => {});
  const url = new URL(req.url, `http://${req.headers.host}`);

  if (url.pathname === "/health") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ ok: true, workspace: WORKSPACE }));
    return;
  }

  if (url.pathname === "/v1/models" || url.pathname === "/models") {
    try {
      const { execSync } = require("child_process");
      const output = execSync(`${CURSOR_BIN} models`, { encoding: "utf8", timeout: 10000 });
      const models = [];
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
  let parsed;
  try {
    parsed = JSON.parse(body || "{}");
  } catch {
    console.error(`[${new Date().toISOString()}] 400: invalid JSON from ${req.socket?.remoteAddress}`);
    res.writeHead(400, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ error: "Invalid JSON" }));
    return;
  }

  const messages = Array.isArray(parsed.messages) ? parsed.messages : [];
  const stream = parsed.stream === true;
  const model = stripModelPrefix(parsed.model);
  const usePartialOutput = process.env.CURSOR_PROXY_PARTIAL === "true";
  const imagePaths = collectImagePaths(messages);
  const hasToolResults = messages.some((m) => m.role === "tool");
  const prompt = hasToolResults
    ? buildPromptWithToolResults(messages, imagePaths)
    : buildPrompt(messages, imagePaths);

  proxyLog(
    `[cursor-proxy] ${req.method} /v1/chat/completions model=${model} msgs=${messages.length} stream=${stream} images=${imagePaths.length} prompt=${prompt.length}ch`
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
    WORKSPACE,
    "--model",
    model,
  ];
  if (usePartialOutput) args.push("--stream-partial-output");

  const child = spawn(CURSOR_BIN, args, {
    stdio: ["pipe", "pipe", "pipe"],
    env: { ...process.env },
  });

  const REQUEST_TIMEOUT = parseInt(process.env.CURSOR_PROXY_TIMEOUT, 10) || 300000;
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

  let usage = null;
  let terminalResult = "";
  let streamed = false;

  const emitTextDelta = (tracker, text) => {
    if (!stream || res.writableEnded || !text) return;
    const delta = tracker ? tracker.nextText(text) : text;
    if (!delta) return;
    res.write(formatSseChunk(id, created, modelId, { content: delta }));
    streamed = true;
  };

  const parseOutputLine = (line, tracker) => {
    const ev = parseLine(line);
    if (!ev) return;

    if (ev.type === "result") {
      if (ev.usage) usage = ev.usage;
      if (typeof ev.result === "string" && ev.result) {
        terminalResult = ev.result;
        // stream-json: only the terminal result carries the final answer; assistant
        // lines between tool calls repeat the same text and duplicate in OpenCode.
        if (stream && !usePartialOutput) emitTextDelta(tracker, ev.result);
      }
      return;
    }

    if (res.writableEnded || !usePartialOutput) return;

    const isPartial = typeof ev.timestamp_ms === "number";
    if (ev.type === "assistant" && Array.isArray(ev.message?.content)) {
      if (stream && !isPartial) return;
      for (const part of ev.message.content) {
        if (part.type === "text" && part.text) {
          emitTextDelta(tracker, part.text);
        }
      }
    }
  };

  const buildFinalResponse = (content) => ({
    id,
    object: "chat.completion",
    created,
    model: modelId,
    choices: [
      {
        index: 0,
        message: { role: "assistant", content: content || "No response" },
        finish_reason: "stop",
      },
    ],
    usage: usage
      ? {
          prompt_tokens: usage.inputTokens || 0,
          completion_tokens: usage.outputTokens || 0,
          total_tokens: (usage.inputTokens || 0) + (usage.outputTokens || 0),
        }
      : undefined,
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
        usage: {
          prompt_tokens: usage.inputTokens || 0,
          completion_tokens: usage.outputTokens || 0,
          total_tokens: (usage.inputTokens || 0) + (usage.outputTokens || 0),
        },
      }) +
      "\n\n"
    );
  };

  if (!stream) {
    const stdoutChunks = [];
    const stderrChunks = [];
    child.stdout.on("data", (c) => stdoutChunks.push(c));
    child.stderr.on("data", (c) => stderrChunks.push(c));
    child.on("close", (code) => {
      clearTimeout(timeout);
      const stdout = Buffer.concat(stdoutChunks).toString().trim();
      const stderr = Buffer.concat(stderrChunks).toString().trim();

      const tracker = new DeltaTracker();
      let content = "";
      for (const line of stdout.split("\n")) {
        const ev = parseLine(line);
        if (!ev) continue;
        if (ev.type === "result") {
          if (ev.usage) usage = ev.usage;
          if (typeof ev.result === "string" && ev.result) content = ev.result;
          continue;
        }
        if (usePartialOutput && ev.type === "assistant" && Array.isArray(ev.message?.content)) {
          for (const part of ev.message.content) {
            if (part.type === "text" && part.text) {
              content += tracker.nextText(part.text);
            }
          }
        }
      }
      if (code !== 0 || (stderr && !content)) {
        content = `Error: ${stderr || `cursor-agent exited with code ${code}`}`;
      }

      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify(buildFinalResponse(content)));
    });
    return;
  }

  res.writeHead(200, {
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache",
    Connection: "keep-alive",
  });

  let buffer = "";
  const tracker = new DeltaTracker();

  child.stdout.on("data", (chunk) => {
    buffer += chunk.toString();
    const lines = buffer.split("\n");
    buffer = lines.pop() || "";
    for (const line of lines) parseOutputLine(line, tracker);
  });

  child.on("close", (code) => {
    clearTimeout(timeout);
    if (buffer) parseOutputLine(buffer, tracker);
    if (!res.writableEnded) {
      const finalText = terminalResult || tracker.text;
      if (stream && !streamed && finalText) {
        emitTextDelta(tracker, finalText);
      }
      const usageChunk = buildSseUsageChunk();
      if (usageChunk) res.write(usageChunk);
      res.write(formatSseFinal(id, created, modelId, undefined));
      res.end();
    }
    proxyLog(
      `[cursor-proxy] stream done id=${id} model=${model} code=${code} streamed=${streamed} chars=${(tracker.text || terminalResult).length}`
    );
  });

  child.on("error", (err) => {
    clearTimeout(timeout);
    console.error(`[${new Date().toISOString()}] spawn error id=${id} model=${model}: ${err.message}`);
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
  if (err.code === "EADDRINUSE") {
    proxyLog(`port ${PORT} already in use, assuming another instance is running`);
    process.exit(0);
  }
  proxyError(`server error: ${err.message}`);
  process.exit(1);
});

server.listen(PORT, "127.0.0.1", () => {
  proxyLog(`[cursor-proxy] listening on http://127.0.0.1:${PORT}`);
});
