/// <reference types="bun-types" />

import { $ } from 'bun';

/**
 * OpenAI-compatible HTTP API that forwards requests to the cursor-agent CLI.
 * Supports GET /v1/models, POST /v1/chat/completions, and POST /v1/responses.
 */

const {
  CURSOR_AGENT_BIN = 'cursor-agent',
  CURSOR_API_KEY = '',
  // CURSOR_AGENT_MODEL_ID = 'cursor-agent',
  CURSOR_AGENT_TIMEOUT = '300',
} = process.env;
const DEFAULT_TIMEOUT_MS = parseInt(CURSOR_AGENT_TIMEOUT, 10) * 1000;

function log(level: 'info' | 'warn' | 'error' | 'debug', msg: string, ...args: unknown[]) {
  const ts = new Date().toISOString();
  const fn =
    level === 'error'
      ? console.error
      : level === 'warn'
      ? console.warn
      : level === 'debug'
      ? console.debug
      : console.log;
  fn(`[${ts}] [${level.toUpperCase()}] ${msg}`, ...args);
}

type Message = {
  role?: string;
  content?: string | Array<{ type?: string; text?: string }>;
};

/** Responses API: input item (message with content list or plain string) */
type ResponseInputItem = {
  type?: string;
  role?: string;
  content?: Array<{ type?: string; text?: string }> | string;
};

function messagesToPrompt(messages: Message[]): string {
  const parts: string[] = [];
  for (const m of messages) {
    const role = m.role ?? 'user';
    let content = m.content;
    if (Array.isArray(content)) {
      content = content
        .filter((c) => c.type === 'text' || c.type === 'input_text')
        .map((c) => c.text ?? '')
        .join(' ');
    }
    if (typeof content !== 'string' || !content.trim()) continue;
    if (role === 'system') parts.push(`System: ${content}`);
    else if (role === 'user') parts.push(`User: ${content}`);
    else if (role === 'assistant') parts.push(`Assistant: ${content}`);
    else if (role === 'developer') parts.push(`Developer: ${content}`);
  }
  return parts.join('\n\n') || '';
}

function inputItemsToPrompt(items: ResponseInputItem[]): string {
  const parts: string[] = [];
  for (const item of items) {
    const role = item.role ?? 'user';
    const content = item.content;
    let text = '';
    if (typeof content === 'string') {
      text = content.trim();
    } else if (Array.isArray(content)) {
      // Accept input_text, text, or any block with .text (e.g. from n8n/other clients)
      text = content
        .filter((c) => c.type === 'input_text' || c.type === 'text' || (c as { text?: string }).text !== undefined)
        .map((c) => (c.text ?? '').trim())
        .join(' ')
        .trim();
    }
    if (!text) continue;
    if (role === 'system') parts.push(`System: ${text}`);
    else if (role === 'user') parts.push(`User: ${text}`);
    else if (role === 'assistant') parts.push(`Assistant: ${text}`);
    else if (role === 'developer') parts.push(`Developer: ${text}`);
  }
  return parts.join('\n\n') || '';
}

async function checkCursorCLI() {
  const proc = await $`${CURSOR_AGENT_BIN} --version`;
  if (proc.exitCode !== 0) throw new Error(`cursor-agent not found`);
}

async function runCursorAgent(
  prompt: string,
  {
    model = 'auto',
    timeoutMs = DEFAULT_TIMEOUT_MS,
    sessionId,
  }: {
    model?: string;
    timeoutMs?: number;
    sessionId?: string;
  } = {}
): Promise<string> {
  if (!CURSOR_API_KEY) throw new Error('CURSOR_API_KEY is not set');
  await checkCursorCLI();
  const proc = Bun.spawn(
    [
      CURSOR_AGENT_BIN,
      '-p',
      '--output-format',
      'json',
      ...(sessionId ? ['--resume', sessionId] : []),
      '--model',
      model,
      prompt,
    ],
    {
      env: { ...process.env, CURSOR_API_KEY },
      stdout: 'pipe',
      stderr: 'pipe',
    }
  );

  const timeout = setTimeout(() => {
    proc.kill();
  }, timeoutMs);

  const [stdout, stderr] = await Promise.all([new Response(proc.stdout).text(), new Response(proc.stderr).text()]);
  const exitCode = await proc.exited;
  clearTimeout(timeout);

  if (exitCode !== 0) {
    throw new Error(`cursor-agent failed (exit ${exitCode}): ${stderr || stdout || 'unknown error'}`);
  }

  const out = stdout.trim();
  try {
    const data = JSON.parse(out) as unknown;
    if (Array.isArray(data)) {
      const texts = data
        .filter(
          (block: unknown): block is { type: string; text: string } =>
            typeof block === 'object' &&
            block !== null &&
            (block as Record<string, unknown>).type === 'text' &&
            typeof (block as Record<string, unknown>).text === 'string'
        )
        .map((block) => block.text);
      if (texts.length > 0) {
        return stripMarkdownCodeFence(texts.join(''));
      }
      return out;
    }
    if (typeof data === 'object' && data !== null) {
      const obj = data as Record<string, unknown>;
      const raw = (obj.result as string) ?? (obj.text as string) ?? (obj.content as string) ?? out;
      const text = typeof raw === 'string' ? raw : out;
      return stripMarkdownCodeFence(text);
    }
    if (typeof data === 'string') return stripMarkdownCodeFence(data);
    return out;
  } catch {
    return out;
  }
}

/** Strip ```json ... ``` or ``` ... ``` so downstream parsers get clean content. */
function stripMarkdownCodeFence(s: string): string {
  const t = s.trim();
  const match = t.match(/^```(?:json)?\s*\n?([\s\S]*?)\n?```$/);
  return match ? match[1].trim() : t;
}

function openaiChatCompletion(content: string, model: string, requestId: string): object {
  return {
    id: requestId,
    object: 'chat.completion',
    created: Math.floor(Date.now() / 1000),
    model,
    choices: [
      {
        index: 0,
        message: { role: 'assistant' as const, content },
        finish_reason: 'stop' as const,
      },
    ],
    usage: { prompt_tokens: 0, completion_tokens: 0, total_tokens: 0 },
  };
}

async function openaiModelsList() {
  const models = await $`${CURSOR_AGENT_BIN} models`.text();
  return {
    object: 'list',
    data: models
      .split('\n')
      .map((line) => {
        line = line.trim();
        if (!line) return null;
        const [id, name] = line.split(' - ').map((s) => s.trim());
        if (!id || !name) return null;
        return {
          id,
          object: 'model',
          created: Math.floor(Date.now() / 1000),
          owned_by: 'cursor',
        };
      })
      .filter(Boolean),
  };
}

function openaiResponseObject(responseText: string, model: string, responseId: string): object {
  return {
    id: responseId,
    object: 'response',
    created: Math.floor(Date.now() / 1000),
    model,
    output: [
      {
        type: 'message',
        role: 'assistant',
        content: [{ type: 'output_text', text: responseText }],
      },
    ],
  };
}

function jsonResponse(status: number, body: object): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

async function handleChatCompletions(req: Request): Promise<Response> {
  const start = Date.now();
  let data: Record<string, unknown>;
  try {
    data = (await req.json()) as Record<string, unknown>;
  } catch (err) {
    log('warn', 'Invalid JSON body', (err as Error).message);
    return jsonResponse(400, {
      error: { message: `Invalid JSON: ${(err as Error).message}` },
    });
  }
  const messages = data.messages as Message[] | undefined;
  if (!messages?.length) {
    log('warn', 'Request missing or empty messages');
    return jsonResponse(400, {
      error: { message: "Missing or empty 'messages'" },
    });
  }
  const model = (data.model as string) ?? 'auto';
  if (data.stream === true) {
    log('info', 'Streaming requested but not supported');
    return jsonResponse(501, {
      error: { message: 'Streaming not yet supported' },
    });
  }
  const timeoutSec = (data.timeout as number) ?? DEFAULT_TIMEOUT_MS / 1000;
  const prompt = messagesToPrompt(messages);
  if (!prompt) {
    log('warn', 'No prompt content in messages');
    return jsonResponse(400, {
      error: { message: 'No prompt content in messages' },
    });
  }
  log('info', 'Chat completion request', { model, promptLength: prompt.length, timeoutSec });
  try {
    const responseText = await runCursorAgent(prompt, { timeoutMs: timeoutSec * 1000, model });
    const elapsed = Date.now() - start;
    log('info', 'Chat completion success', { model, elapsedMs: elapsed, responseLength: responseText.length });
    const requestId = `chatcmpl-${Math.floor(Date.now() / 1000)}`;
    return jsonResponse(200, openaiChatCompletion(responseText, model, requestId) as object);
  } catch (err) {
    const msg = (err as Error).message ?? String(err);
    const elapsed = Date.now() - start;
    log('error', 'Chat completion failed', { model, elapsedMs: elapsed, error: msg });
    if (msg.includes('timed out') || msg.includes('killed'))
      return jsonResponse(504, {
        error: { message: 'cursor-agent timed out' },
      });
    if (msg.includes('CURSOR_API_KEY')) return jsonResponse(500, { error: { message: msg } });
    return jsonResponse(502, { error: { message: msg } });
  }
}

async function handleResponses(req: Request): Promise<Response> {
  const start = Date.now();
  let data: Record<string, unknown>;
  try {
    data = (await req.json()) as Record<string, unknown>;
  } catch (err) {
    log('warn', 'Responses: invalid JSON body', (err as Error).message);
    return jsonResponse(400, {
      error: { message: `Invalid JSON: ${(err as Error).message}` },
    });
  }
  const model = (data.model as string) ?? 'auto';
  let prompt: string;
  const input = data.input;
  const instructions = typeof data.instructions === 'string' ? data.instructions.trim() : '';
  if (Array.isArray(input) && input.length > 0) {
    prompt = inputItemsToPrompt(input as ResponseInputItem[]);
  } else if (
    input &&
    typeof input === 'object' &&
    !Array.isArray(input) &&
    (input as ResponseInputItem).content !== undefined
  ) {
    prompt = inputItemsToPrompt([input as ResponseInputItem]);
  } else if (data.messages && Array.isArray(data.messages)) {
    prompt = messagesToPrompt(data.messages as Message[]);
  } else if (typeof input === 'string' && input.trim()) {
    prompt = input.trim();
  } else if (instructions) {
    prompt = instructions;
  } else {
    log('warn', 'Responses: no input, messages, or input string');
    return jsonResponse(400, {
      error: { message: "Missing or empty 'input' or 'messages'" },
    });
  }
  if (!prompt && instructions) prompt = instructions;
  if (!prompt) {
    log('warn', 'Responses: no prompt content in input/messages');
    return jsonResponse(400, {
      error: { message: 'No prompt content in input or messages' },
    });
  }
  if (instructions && prompt !== instructions) prompt = `System: ${instructions}\n\n${prompt}`;
  const timeoutSec = (data.timeout as number) ?? DEFAULT_TIMEOUT_MS / 1000;
  log('info', 'Responses request', {
    model,
    promptLength: prompt.length,
    timeoutSec,
  });
  try {
    const responseText = await runCursorAgent(prompt, { timeoutMs: timeoutSec * 1000, model });
    const elapsed = Date.now() - start;
    log('info', 'Responses success', {
      model,
      elapsedMs: elapsed,
      responseLength: responseText.length,
    });
    const responseId = `resp_${Math.floor(Date.now() / 1000)}`;
    return jsonResponse(200, openaiResponseObject(responseText, model, responseId) as object);
  } catch (err) {
    const msg = (err as Error).message ?? String(err);
    const elapsed = Date.now() - start;
    log('error', 'Responses failed', {
      model,
      elapsedMs: elapsed,
      error: msg,
    });
    if (msg.includes('timed out') || msg.includes('killed')) {
      return jsonResponse(504, {
        error: { message: 'cursor-agent timed out' },
      });
    }
    if (msg.includes('CURSOR_API_KEY')) {
      return jsonResponse(500, { error: { message: msg } });
    }
    return jsonResponse(502, { error: { message: msg } });
  }
}

const host = process.env.HOST ?? '127.0.0.1';
const port = parseInt(process.env.PORT ?? '8222', 10);

const ok = jsonResponse(200, { status: 'ok' });

async function handleRequest(req: Request): Promise<Response> {
  const url = new URL(req.url);
  log('info', `${req.method} ${url.pathname || '/'}`);
  if (url.pathname === '/v1/models' && req.method === 'GET') {
    return jsonResponse(200, await openaiModelsList());
  }
  if (url.pathname === '/' || url.pathname === '/health' || url.pathname === '/healthz') {
    return ok;
  }
  if (url.pathname === '/v1/chat/completions' && req.method === 'POST') {
    return handleChatCompletions(req);
  }
  if ((url.pathname === '/v1/responses' || url.pathname === '/responses') && req.method === 'POST') {
    return handleResponses(req);
  }
  return jsonResponse(404, { error: { message: 'Not found' } });
}

const server = Bun.serve({
  hostname: host,
  port,
  fetch: handleRequest,
});

if (!CURSOR_API_KEY) {
  log('warn', 'CURSOR_API_KEY not set; /v1/chat/completions will fail');
}
log('info', 'Cursor-agent OpenAI-compat API listening', server.url.href);
