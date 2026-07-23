/** Whether a cursor-agent model id should hold content until thinking completes. */
export function isThinkingModel(modelId: string): boolean {
  return modelId.toLowerCase().includes("thinking");
}

export type StreamOut =
  | { kind: "reasoning"; text: string }
  | { kind: "content"; text: string };

/**
 * Holds assistant content until thinking for the current phase completes so
 * OpenCode sees reasoning before answer text (cursor-agent can emit A→T→A).
 */
export class ContentHold {
  private holdContent: boolean;
  private thinkingActive = false;
  private contentBuffer = "";

  constructor(opts: { enabled: boolean }) {
    this.holdContent = opts.enabled;
  }

  onThinkingDelta(text: string): StreamOut[] {
    if (!text) return [];
    this.thinkingActive = true;
    return [{ kind: "reasoning", text }];
  }

  onThinkingCompleted(): StreamOut[] {
    this.thinkingActive = false;
    this.holdContent = false;
    return this.flush();
  }

  onContent(text: string): StreamOut[] {
    if (!text) return [];
    if (this.holdContent || this.thinkingActive) {
      this.contentBuffer += text;
      return [];
    }
    return [{ kind: "content", text }];
  }

  finish(): StreamOut[] {
    return this.flush();
  }

  private flush(): StreamOut[] {
    if (!this.contentBuffer) return [];
    const text = this.contentBuffer;
    this.contentBuffer = "";
    return [{ kind: "content", text }];
  }
}

/** Synthetic agent events for ordering tests (mirrors what the proxy maps). */
export type AgentEvent =
  | { type: "thinking"; subtype: "delta"; text: string }
  | { type: "thinking"; subtype: "completed" }
  | { type: "assistant"; text: string };

/** Project agent events through ContentHold the same way the stream handler does. */
export function projectAgentEvents(
  events: AgentEvent[],
  opts: { holdEnabled: boolean }
): StreamOut[] {
  const hold = new ContentHold({ enabled: opts.holdEnabled });
  const out: StreamOut[] = [];
  for (const ev of events) {
    if (ev.type === "thinking" && ev.subtype === "delta") {
      out.push(...hold.onThinkingDelta(ev.text));
    } else if (ev.type === "thinking" && ev.subtype === "completed") {
      out.push(...hold.onThinkingCompleted());
    } else if (ev.type === "assistant") {
      out.push(...hold.onContent(ev.text));
    }
  }
  out.push(...hold.finish());
  return out;
}
