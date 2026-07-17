import { strict as assert } from "node:assert";
import { mkdirSync, rmSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createDemoFixtureAdapters } from "../tools/hq-dispatch/v1/demo-fixtures.mjs";
import { HqMissionRelay } from "../tools/hq-dispatch/v1/mission-relay.mjs";
import { POWERSHELL_EXE, reconcileCanonicalState } from "../tools/hq-dispatch/v1/reliability.mjs";

const root = path.resolve(fileURLToPath(new URL("../", import.meta.url)));
const fixtureRoot = path.join(root, ".codex-local", "fixtures", "hq-dispatch-restart-tim-v1");
const runtimeRoot = path.join(fixtureRoot, "runtime");
const queueRoot = path.join(fixtureRoot, "queue");
rmSync(fixtureRoot, { recursive: true, force: true });
mkdirSync(runtimeRoot, { recursive: true });
mkdirSync(queueRoot, { recursive: true });
const adapters = createDemoFixtureAdapters({ fixtureRoot, repositoryRoot: root, queueRoot, runtimeRoot });
const missionId = "hq-restart-tim-fixture-0001";
adapters.timOutcome(missionId, 1, "TIM REQUIRED restart fixture");
const reconciliation = reconcileCanonicalState({ runtimeRoot, queueRoot });
const item = reconciliation.items.find((candidate) => candidate.classification === "TIM_REQUIRED_PENDING_RESPONSE");
assert.ok(item);

const relay = new HqMissionRelay({ repositoryRoot: root, powershellExe: POWERSHELL_EXE, invokePreview: async () => { throw new Error("NOT_USED"); }, responseAdapter: adapters.responseAdapter, executionAdapter: adapters.executionAdapter });
const sessionKey = "restart-session-key";
const status = relay.loadReconciledTimRequired(item, sessionKey);
assert.equal(status.state, "TIM_REQUIRED");
assert.equal(status.restart_reconciled, true);
assert.equal(status.automatic_rerun_performed, false);
assert.equal(status.old_thread_or_turn_resumed, false);
const request = status.tim_request;
const response = await relay.respond({ mission_id: request.mission_id, mission_revision: request.mission_revision, run_id: request.run_id, result_id: request.result_id, tim_required_request_id: request.request_id, request_evidence_sha256: request.evidence_sha256, response_id: request.response_id, response_type: "PROVIDE_CLARIFICATION", operator_confirmation: "PROVIDE CLARIFICATION", response_payload: "Proceed only through the deterministic canonical fixture revision." }, sessionKey);
assert.equal(response.mission_revision, 2);
assert.notEqual(response.run_id, request.run_id);
assert.equal(response.prior_terminal.state, "TIM_REQUIRED");
assert.equal(response.worker.thread_id.includes("-r2"), true);
assert.equal(relay.activeChild, null);
await relay.shutdown();

console.log(JSON.stringify({ schema_version: "tsf_hq_dispatch_restart_tim_proof_v1", status: "PASS", original_run_id: request.run_id, new_run_id: response.run_id, original_run_immutable: true, old_thread_or_turn_resumed: false, automatic_response: false }, null, 2));
