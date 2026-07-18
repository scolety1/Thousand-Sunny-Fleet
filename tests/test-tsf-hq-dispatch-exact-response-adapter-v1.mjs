import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(fileURLToPath(new URL("..", import.meta.url)));
const fixtureRoot = path.join(root, ".codex-local", "fixtures", "hq-dispatch-exact-adapter");
const adapterPath = path.join(root, "tools", "tsf-codex-app-server-adapter.mjs");
const fakePath = path.join(fixtureRoot, "fake-app-server.mjs");
const expected = "TSF_HQ_DISPATCH_READ_ONLY_GREEN";
const expectedHash = createHash("sha256").update(expected).digest("hex");
const missionId = "hq2-exact-adapter-test";
const runId = `canonical-result-${missionId}-1`;
let assertions = 0;

function check(value, message) { assertions += 1; assert.ok(value, message); }
function equal(actual, expectedValue, message) { assertions += 1; assert.equal(actual, expectedValue, message); }

rmSync(fixtureRoot, { recursive: true, force: true });
mkdirSync(fixtureRoot, { recursive: true });
writeFileSync(fakePath, `
import { createInterface } from "node:readline";
const responseMode = process.env.TSF_FAKE_RESPONSE_MODE ?? "present";
const responseText = process.env.TSF_FAKE_RESPONSE ?? "";
const threadId = "thread-exact-adapter-test";
const turnId = "turn-exact-adapter-test";
const write = (value) => process.stdout.write(JSON.stringify(value) + "\\n");
createInterface({ input: process.stdin, crlfDelay: Infinity }).on("line", (line) => {
  const message = JSON.parse(line);
  if (message.method === "initialize") write({ id: message.id, result: { userAgent: "tsf-test" } });
  else if (message.method === "model/list") write({ id: message.id, result: { data: [{ id: "gpt-5.6-terra", supportedReasoningEfforts: [{ reasoningEffort: "medium" }] }] } });
  else if (message.method === "thread/start") write({ id: message.id, result: { thread: { id: threadId }, model: "gpt-5.6-terra", reasoningEffort: "medium", cwd: process.cwd(), approvalPolicy: "never", sandbox: { networkAccess: false } } });
  else if (message.method === "turn/start") {
    write({ id: message.id, result: { turn: { id: turnId } } });
    write({ method: "turn/started", params: { threadId, turn: { id: turnId, status: "inProgress" } } });
    if (responseMode !== "missing") write({ method: "item/completed", params: { threadId, turnId, item: { id: "item-exact", type: "agentMessage", text: responseText } } });
    write({ method: "turn/completed", params: { threadId, turn: { id: turnId, status: "completed" } } });
  }
});
`, "utf8");

function runCase(name, response, mode = "present") {
  const output = path.join(fixtureRoot, name);
  mkdirSync(output, { recursive: true });
  const resultFile = path.join(output, "adapter-result.json");
  const eventFile = path.join(output, "events.jsonl");
  const stderrFile = path.join(output, "stderr.txt");
  const promptFile = path.join(output, "prompt.txt");
  writeFileSync(promptFile, "Return the mission-bound exact response.", "utf8");
  const child = spawnSync(process.execPath, [
    adapterPath,
    "--codex-executable", fakePath,
    "--mission-id", missionId,
    "--mission-revision", "1",
    "--policy-fingerprint", "a".repeat(64),
    "--queue-document-sha256", "b".repeat(64),
    "--run-id", runId,
    "--result-id", runId,
    "--cwd", root,
    "--model", "gpt-5.6-terra",
    "--mission-requested-effort", "MEDIUM",
    "--canonical-resolved-effort", "MEDIUM",
    "--required-effort-assurance", "RECOMMENDED_ONLY",
    "--effort", "medium",
    "--sandbox", "read-only",
    "--prompt-file", promptFile,
    "--output-dir", output,
    "--result-file", resultFile,
    "--event-file", eventFile,
    "--stderr-file", stderrFile,
    "--timeout-seconds", "10",
    "--expires-at", "2099-01-01T00:00:00.000Z",
    "--expected-response-sha256", expectedHash,
  ], {
    cwd: root,
    encoding: "utf8",
    timeout: 20_000,
    env: { ...process.env, TSF_FAKE_RESPONSE_MODE: mode, TSF_FAKE_RESPONSE: response },
  });
  equal(child.status, 0, `${name}: semantic mismatch does not falsify transport exit`);
  return JSON.parse(readFileSync(resultFile, "utf8"));
}

function runSpawnFailureCase() {
  const output = path.join(fixtureRoot, "spawn-failure");
  mkdirSync(output, { recursive: true });
  const resultFile = path.join(output, "adapter-result.json");
  const eventFile = path.join(output, "events.jsonl");
  const stderrFile = path.join(output, "stderr.txt");
  const promptFile = path.join(output, "prompt.txt");
  writeFileSync(promptFile, "This request must never reach a worker.", "utf8");
  const child = spawnSync(process.execPath, [
    adapterPath,
    "--codex-executable", path.join(output, "missing-app-server.exe"),
    "--mission-id", missionId,
    "--mission-revision", "1",
    "--policy-fingerprint", "a".repeat(64),
    "--queue-document-sha256", "b".repeat(64),
    "--run-id", runId,
    "--result-id", runId,
    "--cwd", root,
    "--model", "gpt-5.6-terra",
    "--mission-requested-effort", "MEDIUM",
    "--canonical-resolved-effort", "MEDIUM",
    "--required-effort-assurance", "RECOMMENDED_ONLY",
    "--effort", "medium",
    "--sandbox", "read-only",
    "--prompt-file", promptFile,
    "--output-dir", output,
    "--result-file", resultFile,
    "--event-file", eventFile,
    "--stderr-file", stderrFile,
    "--timeout-seconds", "10",
    "--expires-at", "2099-01-01T00:00:00.000Z",
  ], { cwd: root, encoding: "utf8", timeout: 20_000 });
  equal(child.status, 1, "spawn failure exits nonzero");
  const result = JSON.parse(readFileSync(resultFile, "utf8"));
  const journal = readFileSync(eventFile, "utf8").trim().split(/\r?\n/).filter(Boolean).map(JSON.parse);
  equal(result.transport_success, false, "spawn failure is not transport success");
  equal(result.failure_classification, "AUTHORITATIVE_APP_SERVER_SPAWN_OR_INSPECTION_FAILED", "spawn failure has a closed classification");
  equal(result.failure_stage, "AUTHORITATIVE_APP_SERVER_SPAWN_INSPECTION", "spawn failure records the exact stage");
  check(typeof result.failure === "string" && result.failure.length > 0, "spawn failure preserves its exact error");
  equal(journal.at(-1)?.message?.event_type, "AUTHORITATIVE_APP_SERVER_SPAWN_FAILURE", "spawn failure is journaled before result serialization");
}

try {
  const exact = runCase("exact", expected);
  equal(exact.transport_success, true, "literal expected response has transport success");
  equal(exact.semantic_response_success, true, "literal expected response has semantic success");
  equal(exact.response_exact_match, true, "literal expected response matches exactly");
  equal(exact.observed_response_sha256, expectedHash, "literal response hash is behavior-derived");
  equal(exact.run_id, runId, "response evidence is run-bound");
  equal(exact.result_id, runId, "response evidence is result-bound");
  check(exact.thread_id && exact.turn_id, "response evidence is thread/turn-bound");

  const rejected = [
    ["wrong-nonempty", "WRONG_NONEMPTY", "present"],
    ["empty", "", "present"],
    ["missing", "", "missing"],
    ["prefix", `prefix${expected}`, "present"],
    ["suffix", `${expected}suffix`, "present"],
    ["case", expected.toLowerCase(), "present"],
    ["space", `${expected} `, "present"],
    ["newline", `${expected}\n`, "present"],
  ];
  for (const [name, response, mode] of rejected) {
    const result = runCase(name, response, mode);
    equal(result.transport_success, true, `${name}: transport remains a separate successful fact`);
    equal(result.semantic_response_success, false, `${name}: semantic result fails closed`);
    equal(result.response_exact_match, false, `${name}: exact comparison rejects mismatch`);
  }

  runSpawnFailureCase();

  const runnerSource = readFileSync(path.join(root, "tests", "run-tsf-hq-dispatch-real-readonly-v1.mjs"), "utf8");
  check(!/product_repository_used\s*:\s*false/.test(runnerSource), "real proof no longer hardcodes product non-use boolean");
  check(!/plugin_used\s*:\s*false/.test(runnerSource), "real proof no longer hardcodes plugin non-use boolean");
  check(runnerSource.includes("POLICY_PROHIBITED") && runnerSource.includes("NOT_OBSERVED") && runnerSource.includes("OBSERVED_NOT_USED"), "real proof preserves policy/observation distinctions");
} finally {
  rmSync(fixtureRoot, { recursive: true, force: true });
}

process.stdout.write(`HQ_DISPATCH_EXACT_ADAPTER_PASS assertions=${assertions}\n`);
