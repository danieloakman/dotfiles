/** Hold content until finish so late thinking (Auto / tool loops) cannot land after the answer. */
export function shouldHoldContent(modelId: string): boolean {
  const m = modelId.toLowerCase();
  return m.includes("thinking") || m === "auto";
}

/** @deprecated use shouldHoldContent */
export function isThinkingModel(modelId: string): boolean {
  return shouldHoldContent(modelId);
}

export type StreamOut =
  | { kind: "reasoning"; text: string }
  | { kind: "content"; text: string };

/**
 * Join fragments without gluing sentence boundaries ("foo.Bar").
 * Space only when left ends a sentence and right starts uppercase — avoids
 * breaking token streams like "3." + "14".
 */
export function joinFragments(left: string, right: string): string {
  if (!left) return right;
  if (!right) return left;
  if (/\s$/.test(left) || /^\s/.test(right)) return left + right;
  if (/[.!?…]["'”’)\]]*$/.test(left) && /^[A-Z]/.test(right)) {
    return left + " " + right;
  }
  return left + right;
}

/** Delta after prior content, including any joinFragments spacer. */
export function spacedFragment(prior: string, next: string): string {
  if (!next) return "";
  if (!prior) return next;
  return joinFragments(prior, next).slice(prior.length);
}

/**
 * Streams reasoning live; buffers content until finish().
 * cursor-agent often emits T→A→T→A; holding until stream end keeps reasoning before the answer.
 */
export class ContentHold {
  private holdContent: boolean;
  private contentBuffer = "";
  private emittedContent = "";

  constructor(opts: { enabled: boolean }) {
    this.holdContent = opts.enabled;
  }

  onThinkingDelta(text: string): StreamOut[] {
    if (!text) return [];
    // Keep holding even if hold started disabled mid-stream.
    this.holdContent = true;
    return [{ kind: "reasoning", text }];
  }

  onThinkingCompleted(): StreamOut[] {
    return [];
  }

  onContent(text: string): StreamOut[] {
    if (!text) return [];
    if (this.holdContent) {
      this.contentBuffer = joinFragments(this.contentBuffer, text);
      return [];
    }
    const out = spacedFragment(this.emittedContent, text);
    this.emittedContent += out;
    return [{ kind: "content", text: out }];
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

/** Test stand-ins for proxy-mapped agent events. */
export type AgentEvent =
  | { type: "thinking"; subtype: "delta"; text: string }
  | { type: "thinking"; subtype: "completed" }
  | { type: "assistant"; text: string };

/** Run events through ContentHold as the stream handler does. */
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
