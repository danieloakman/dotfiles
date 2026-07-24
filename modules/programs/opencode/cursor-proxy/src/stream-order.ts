/**
 * Whether a model should hold assistant content until the stream ends so that
 * late thinking (common with Auto / tool loops) cannot land after the answer.
 */
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
 * Join assistant fragments without gluing sentence boundaries.
 * cursor-agent often emits complete status lines as separate events; naive
 * concat yields "foo.Bar". Only insert a space when the left side ends a
 * sentence and the right starts with an uppercase letter (avoids breaking
 * token streams like "3." + "14").
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

/** Leading spacer (if any) + right, for streaming deltas after prior content. */
export function spacedFragment(prior: string, next: string): string {
  if (!next) return "";
  if (!prior) return next;
  return joinFragments(prior, next).slice(prior.length);
}

/**
 * Streams reasoning live and buffers assistant content until finish().
 *
 * cursor-agent often emits: T → A → T → A (post-tool thinking after answer
 * text already started). Flushing content on thinking:completed lets later
 * reasoning appear after the final answer in OpenCode. Holding until the
 * stream ends keeps all reasoning before the answer.
 */
export class ContentHold {
  private holdContent: boolean;
  private contentBuffer = "";
  /** Last content text emitted live (when not holding), for spacing. */
  private emittedContent = "";

  constructor(opts: { enabled: boolean }) {
    this.holdContent = opts.enabled;
  }

  onThinkingDelta(text: string): StreamOut[] {
    if (!text) return [];
    // Thinking appeared — keep holding content even if hold started disabled
    // mid-stream (defensive) or after an earlier mistaken release.
    this.holdContent = true;
    return [{ kind: "reasoning", text }];
  }

  onThinkingCompleted(): StreamOut[] {
    // Do not flush: more thinking may arrive after tools / later phases.
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
