import { createInterface } from "node:readline";

const mode = process.env.TSF_FAKE_APP_SERVER_MODE ?? "normal";
const rl = createInterface({ input: process.stdin, crlfDelay: Infinity });
function write(value) { process.stdout.write(`${typeof value === "string" ? value : JSON.stringify(value)}\n`); }

rl.on("line", (line) => {
  let request;
  try { request = JSON.parse(line); } catch { return; }
  if (mode === "malformed") { write("not-json"); return; }
  if (mode === "timeout") return;
  if (mode === "exit") { process.exit(7); }
  if (request.method === "initialize") {
    write({ id: request.id, result: { userAgent: "fake-codex/1.0", codexHome: "fixture", platformFamily: "windows", platformOs: "windows" } });
  } else if (request.method === "model/list") {
    write({ id: request.id, result: { data: [{ id: "gpt-5.6-luna", supportedReasoningEfforts: [{ reasoningEffort: "low" }] }], nextCursor: null } });
  } else if (request.method === "thread/start") {
    const reasoningEffort = mode === "effort-match" ? "low" : "high";
    write({ id: request.id, result: { thread: { id: "fake-thread-1" }, model: "gpt-5.6-luna", reasoningEffort, cwd: request.params.cwd, approvalPolicy: "never", sandbox: { type: "readOnly", networkAccess: false } } });
  } else if (request.method === "turn/start") {
    write({ id: request.id, result: { turn: { id: "fake-turn-1" } } });
    const threadId = mode === "spoof" ? "spoofed-thread" : "fake-thread-1";
    const started = { method: "turn/started", params: { threadId, turn: { id: "fake-turn-1", status: "inProgress" } } };
    const item = { method: "item/completed", params: { threadId, turnId: "fake-turn-1", item: { id: "fake-item-1", type: "agentMessage", text: "TSF_FAKE_GREEN" } } };
    const completed = { method: "turn/completed", params: { threadId, turn: { id: "fake-turn-1", status: "completed", usage: { inputTokens: 1, outputTokens: 1 } } } };
    const usage = (totalTokens, inputTokens = totalTokens - 2) => ({ method: "thread/tokenUsage/updated", params: { threadId, turnId: "fake-turn-1", tokenUsage: { total: { totalTokens, inputTokens, cachedInputTokens: 1, outputTokens: 2, reasoningOutputTokens: 0 }, last: { totalTokens, inputTokens, cachedInputTokens: 1, outputTokens: 2, reasoningOutputTokens: 0 }, modelContextWindow: 1000 } } });
    if (mode === "effort-match") write({ method: "thread/settings/updated", params: { threadId, threadSettings: { effort: "low" } } });
    if (mode === "effort-mismatch") write({ method: "thread/settings/updated", params: { threadId, threadSettings: { effort: "high" } } });
    if (mode === "reroute") write({ method: "model/rerouted", params: { threadId, turnId: "fake-turn-1", fromModel: "gpt-5.6-luna", toModel: "gpt-5.6-terra", reason: "highRiskCyberActivity" } });
    if (mode === "usage-mismatch") write({ ...usage(10), params: { ...usage(10).params, turnId: "spoofed-turn" } });
    if (mode === "usage-malformed") write({ method: "thread/tokenUsage/updated", params: { threadId, turnId: "fake-turn-1", tokenUsage: { total: { totalTokens: "ten" } } } });
    if (mode === "usage-multiple") { write(usage(10)); write(usage(20)); }
    else if (mode === "usage-duplicate") { write(usage(10)); write(usage(10)); }
    else if (mode === "usage-out-of-order") { write(usage(20)); write(usage(10)); }
    else if (mode !== "usage-absent" && mode !== "usage-mismatch" && mode !== "usage-malformed") write(usage(10));
    if (mode === "out-of-order") { write(item); write(started); write(completed); }
    else if (mode === "duplicate") { write(started); write(started); write(item); write(completed); }
    else { write(started); write(item); write(completed); }
  }
});
