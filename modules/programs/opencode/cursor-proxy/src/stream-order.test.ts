import assert from "node:assert/strict";
import {
  isThinkingModel,
  projectAgentEvents,
  type AgentEvent,
  type StreamOut,
} from "./stream-order.js";

function kinds(outs: StreamOut[]): string[] {
  return outs.map((o) => o.kind);
}

function firstContentIndex(outs: StreamOut[]): number {
  return outs.findIndex((o) => o.kind === "content");
}

function lastReasoningIndex(outs: StreamOut[]): number {
  let last = -1;
  for (let i = 0; i < outs.length; i++) {
    if (outs[i].kind === "reasoning") last = i;
  }
  return last;
}

function assertReasoningBeforeContent(outs: StreamOut[], label: string) {
  const firstC = firstContentIndex(outs);
  const lastR = lastReasoningIndex(outs);
  assert.ok(lastR >= 0, `${label}: expected reasoning`);
  assert.ok(firstC >= 0, `${label}: expected content`);
  assert.ok(
    lastR < firstC,
    `${label}: expected all reasoning before content, got ${kinds(outs).join(",")}`
  );
}

assert.equal(isThinkingModel("claude-4.6-opus-max-thinking"), true);
assert.equal(isThinkingModel("claude-4.6-opus-max"), false);
assert.equal(isThinkingModel("auto"), false);

{
  const events: AgentEvent[] = [
    { type: "assistant", text: "Checking now." },
    { type: "thinking", subtype: "delta", text: "Count entries." },
    { type: "thinking", subtype: "completed" },
    { type: "assistant", text: "322 entries." },
  ];
  const held = projectAgentEvents(events, { holdEnabled: true });
  assertReasoningBeforeContent(held, "A→T→A hold");
  assert.deepEqual(
    held.map((o) => o.text),
    ["Count entries.", "Checking now.", "322 entries."]
  );

  const passthrough = projectAgentEvents(events, { holdEnabled: false });
  assert.deepEqual(kinds(passthrough), [
    "content",
    "reasoning",
    "content",
  ]);
}

{
  const events: AgentEvent[] = [
    { type: "thinking", subtype: "delta", text: "Sky is blue via Rayleigh." },
    { type: "thinking", subtype: "completed" },
    { type: "assistant", text: "Rayleigh scattering." },
  ];
  const held = projectAgentEvents(events, { holdEnabled: true });
  assertReasoningBeforeContent(held, "T→A hold");
  assert.deepEqual(
    held.map((o) => o.text),
    ["Sky is blue via Rayleigh.", "Rayleigh scattering."]
  );
}

{
  const events: AgentEvent[] = [
    { type: "assistant", text: "4" },
  ];
  const held = projectAgentEvents(events, { holdEnabled: true });
  assert.deepEqual(held, [{ kind: "content", text: "4" }]);

  const live = projectAgentEvents(events, { holdEnabled: false });
  assert.deepEqual(live, [{ kind: "content", text: "4" }]);
}

{
  const events: AgentEvent[] = [
    { type: "thinking", subtype: "delta", text: "First." },
    { type: "thinking", subtype: "completed" },
    { type: "assistant", text: "Mid." },
    { type: "thinking", subtype: "delta", text: "Second." },
    { type: "thinking", subtype: "completed" },
    { type: "assistant", text: "End." },
  ];
  const held = projectAgentEvents(events, { holdEnabled: true });
  assert.deepEqual(
    held.map((o) => `${o.kind}:${o.text}`),
    ["reasoning:First.", "content:Mid.", "reasoning:Second.", "content:End."]
  );
}

console.log("stream-order tests passed");
