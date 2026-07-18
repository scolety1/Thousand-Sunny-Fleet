import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import { HqMissionRelay } from "../tools/hq-dispatch/v1/mission-relay.mjs";
import { createHqDispatchServer, listenHqDispatchServer } from "../tools/hq-dispatch/v1/server.mjs";

let assertions = 0;
const check = (value, message) => { assertions += 1; assert.ok(value, message); };
const equal = (actual, expected, message) => { assertions += 1; assert.equal(actual, expected, message); };
const requiredStages = [
  "STOP_REQUEST_RECEIVED", "NEW_SUBMISSIONS_BLOCKED", "ACTIVE_MISSION_SNAPSHOTTED",
  "OWNED_PROCESS_SET_SNAPSHOTTED", "COOPERATIVE_STOP_REQUESTED", "COOPERATIVE_WAIT_STARTED",
  "CHILD_EXIT_OBSERVED", "TERMINAL_PROCESS_DISPOSITION_RECORDED", "PROCESS_LEDGER_FLUSHED",
  "STOP_RECORD_DURABLE", "BARRIER_READY_CLEANED", "OWNER_EVIDENCE_ARCHIVED", "LIVE_OWNER_REMOVED",
  "SESSION_INVALIDATED", "LISTENER_CLOSE_STARTED", "LISTENER_CLOSED", "STOP_RESPONSE_FINALIZED",
  "SERVER_EXIT_PERMITTED",
];

function deferred() {
  let resolve;
  let reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
}

function readTrace(tracePath) {
  return readFileSync(tracePath, "utf8").split(/\r?\n/).filter(Boolean).map((line) => JSON.parse(line));
}

function validateOrder(events) {
  equal(events.length, requiredStages.length, "successful coordinator writes every required shutdown phase exactly once");
  equal(new Set(events.map((event) => event.sequence)).size, events.length, "shutdown phase sequence is unique");
  equal(events.every((event, index) => event.sequence === index + 1), true, "shutdown phase sequence is monotonic");
  equal(JSON.stringify(events.map((event) => event.stage)), JSON.stringify(requiredStages), "server exit permission follows finalized cleanup and response");
  equal(events.every((event) => /^[a-f0-9]{64}$/.test(event.evidence_sha256)), true, "every shutdown phase is hash bound");
}

function fixtureLifecycle(root) {
  const ownerPath = path.join(root, "owner.json");
  const serverInstanceId = `shutdown-instance-${randomUUID()}`;
  const ownerRecord = {
    server_instance_id: serverInstanceId,
    active_mission: { mission_id: "hq2-shutdown-synthetic", mission_revision: 1, run_id: "run-shutdown-synthetic", result_id: "result-shutdown-synthetic" },
    owned_children: [{ process_id: 41001, process_start_time: "2026-07-19T00:00:00.000Z", executable: "synthetic.exe" }],
    owned_child_process_ids: [41001],
  };
  mkdirSync(root, { recursive: true });
  writeFileSync(ownerPath, `${JSON.stringify(ownerRecord)}\n`, "utf8");
  const owner = {
    ownerPath,
    owner: ownerRecord,
    stoppingCalls: 0,
    releaseCalls: 0,
    stopping() { this.stoppingCalls += 1; },
    release() { this.releaseCalls += 1; rmSync(ownerPath, { force: true }); this.owner = null; },
  };
  return {
    mode: "SHUTDOWN_COORDINATOR_SYNTHETIC",
    owner,
    localRoot: root,
    serverInstanceId,
    sessionGeneration: "session-generation-synthetic",
    authenticateStop: () => true,
    shutdownEvidence: () => ({ cleanup_summary: { terminal_dispositions: [{ process_id: 41001, terminal_disposition: "COOPERATIVE_EXIT_CONFIRMED" }], process_action_ledger_path: "synthetic-ledger", process_action_ledger_sha256: "a".repeat(64) } }),
    finalizeOwnedCleanupCalls: 0,
    async finalizeOwnedCleanup() { this.finalizeOwnedCleanupCalls += 1; },
  };
}

async function stopRequest(port, lifecycle) {
  return fetch(`http://127.0.0.1:${port}/api/v1/admin/stop`, {
    method: "POST",
    headers: { "Content-Type": "application/json", "X-TSF-HQ-Stop": "synthetic-local-capability" },
    body: JSON.stringify({ server_instance_id: lifecycle.serverInstanceId, evidence_hash: "synthetic-evidence", process_id: process.pid }),
  });
}

const killedRelay = new HqMissionRelay({
  repositoryRoot: process.cwd(), powershellExe: "powershell.exe", invokePreview: async () => ({}),
  terminateOwnedChild: async () => { killedCleanupCalls += 1; killedRelay.activeChild = null; killedRelay.activeChildClosed = null; },
});
let killedCleanupCalls = 0;
killedRelay.activeChild = { pid: 41002, killed: true };
killedRelay.activeChildClosed = Promise.resolve();
await killedRelay.shutdown("SYNTHETIC_KILLED_FLAG_NOT_EXIT_EVIDENCE");
equal(killedCleanupCalls, 1, "ChildProcess.killed never bypasses the registered exact cleanup callback");

const successRoot = mkdtempSync(path.join(os.tmpdir(), "tsf-shutdown-success-"));
const successLifecycle = fixtureLifecycle(successRoot);
const gate = deferred();
let shutdownCalls = 0;
const relay = {
  activeChild: null,
  async shutdown() {
    shutdownCalls += 1;
    await gate.promise;
    return { child_exited: true, interrupted_mission_id: "hq2-shutdown-synthetic", interruption: { stop_record_path: "synthetic-stop-record", interruption_identity_sha256: "b".repeat(64) } };
  },
};
const server = await listenHqDispatchServer(createHqDispatchServer({ lifecycle: successLifecycle, relay }), 0);
const port = server.address().port;
const first = stopRequest(port, successLifecycle);
const second = stopRequest(port, successLifecycle);
await new Promise((resolve) => setTimeout(resolve, 50));
equal(shutdownCalls, 1, "concurrent Stop calls share one authoritative shutdown promise");
equal(successLifecycle.owner.releaseCalls, 0, "live owner remains while exact cleanup is pending");
gate.resolve();
const [firstResponse, secondResponse] = await Promise.all([first, second]);
equal(firstResponse.status, 202, "first Stop returns only after cleanup confirmation");
equal(secondResponse.status, 202, "concurrent Stop returns the identical canonical disposition");
const [firstBody, secondBody] = await Promise.all([firstResponse.json(), secondResponse.json()]);
equal(firstBody.shutdown.stop_request_identity_sha256, secondBody.shutdown.stop_request_identity_sha256, "concurrent Stop results share one identity");
equal(successLifecycle.owner.releaseCalls, 1, "owner is removed exactly once after cleanup");
equal(successLifecycle.finalizeOwnedCleanupCalls, 1, "barrier/owned cleanup finalizer runs exactly once");
check(!existsSync(successLifecycle.owner.ownerPath), "owner archive/removal completes before Stop response");
await new Promise((resolve) => setTimeout(resolve, 25));
validateOrder(readTrace(firstBody.shutdown.shutdown_trace_path));

const failureRoot = mkdtempSync(path.join(os.tmpdir(), "tsf-shutdown-failure-"));
const failureLifecycle = fixtureLifecycle(failureRoot);
let rejectedCleanupCalls = 0;
const failedServer = await listenHqDispatchServer(createHqDispatchServer({
  lifecycle: failureLifecycle,
  relay: { activeChild: {}, async shutdown() { rejectedCleanupCalls += 1; throw new Error("CLEANUP_UNCONFIRMED"); } },
}), 0);
const failedResponse = await stopRequest(failedServer.address().port, failureLifecycle);
equal(failedResponse.status, 503, "cleanup rejection fails Stop closed");
equal(rejectedCleanupCalls, 1, "cleanup rejection is not retried or duplicated");
equal(existsSync(failureLifecycle.owner.ownerPath), true, "cleanup failure preserves live owner evidence");
equal(failureLifecycle.owner.releaseCalls, 0, "cleanup failure never removes owner evidence");
equal(failedServer.listening, true, "cleanup failure does not pretend listener finalization succeeded");
await new Promise((resolve) => failedServer.close(resolve));

rmSync(successRoot, { recursive: true, force: true });
rmSync(failureRoot, { recursive: true, force: true });
process.stdout.write(`${JSON.stringify({ schema_version: "tsf_hq_dispatch_shutdown_coordinator_adversarial_v1", status: "PASS", assertions, required_stage_count: requiredStages.length })}\n`);
