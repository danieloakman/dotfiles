import assert from "node:assert/strict";
import {
  shouldHoldContent,
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

assert.equal(shouldHoldContent("claude-4.6-opus-max-thinking"), true);
assert.equal(shouldHoldContent("auto"), true);
assert.equal(shouldHoldContent("claude-4.6-opus-max"), false);
assert.equal(shouldHoldContent("composer-2.5"), false);

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
    ["Count entries.", "Checking now.322 entries."]
  );

  const passthrough = projectAgentEvents(events, { holdEnabled: false });
  // Without initial hold, first A escapes before thinking enables hold;
  // remaining content still waits until finish after thinking appears.
  assert.deepEqual(
    passthrough.map((o) => `${o.kind}:${o.text}`),
    ["content:Checking now.", "reasoning:Count entries.", "content:322 entries."]
  );
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
  // Matches the live Auto session: T → A(final) → T → T
  const events: AgentEvent[] = [
    { type: "thinking", subtype: "delta", text: "Checking the date planning." },
    { type: "thinking", subtype: "completed" },
    { type: "assistant", text: "Wed 29 Jul evening — best fit." },
    { type: "thinking", subtype: "delta", text: "I need to read the calendar." },
    { type: "thinking", subtype: "completed" },
    { type: "thinking", subtype: "delta", text: "Planning evening activities." },
    { type: "thinking", subtype: "completed" },
  ];
  const held = projectAgentEvents(events, { holdEnabled: true });
  assertReasoningBeforeContent(held, "T→A→T→T late thinking");
  assert.deepEqual(
    held.map((o) => `${o.kind}:${o.text}`),
    [
      "reasoning:Checking the date planning.",
      "reasoning:I need to read the calendar.",
      "reasoning:Planning evening activities.",
      "content:Wed 29 Jul evening — best fit.",
    ]
  );
}

{
  const events: AgentEvent[] = [{ type: "assistant", text: "4" }];
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
    ["reasoning:First.", "reasoning:Second.", "content:Mid.End."]
  );
}

console.log("stream-order tests passed");
