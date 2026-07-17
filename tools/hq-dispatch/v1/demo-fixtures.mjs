import { createHash, randomUUID } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import path from "node:path";

function hash(value) { return createHash("sha256").update(value).digest("hex"); }
function json(filePath, value) { mkdirSync(path.dirname(filePath), { recursive: true }); writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`, "utf8"); }
function fileHash(filePath) { return hash(readFileSync(filePath)); }

export function createDemoFixtureAdapters({ fixtureRoot, repositoryRoot, queueRoot, runtimeRoot }) {
  const route = { worker_role: "researcher_source_tracer_worker", resolved_model: "gpt-5.6-terra", effort: "MEDIUM" };
  const access = { permission_mode: "READ_ONLY", network_policy: "PROHIBITED", control_plane_service_network_policy: "CODEX_SERVICE_ONLY", worker_tool_network_policy: "DISABLED", allowed_reads: ["fleet/control/policy-manifest.v1.json"], allowed_writes: [] };

  function pathsFor(missionId, revision) {
    const runId = `canonical-result-${missionId}-${revision}`;
    const base = path.join(runtimeRoot, missionId, `r${revision}`);
    return {
      runId,
      base,
      mission: path.join(base, "gm.json"),
      queueRuntime: path.join(base, "qd.json"),
      queueResult: path.join(base, "qe.json"),
      lifecycle: path.join(base, "lc.json"),
      adapter: path.join(base, "ar.json"),
      verifier: path.join(base, "vr.json"),
      worker: path.join(base, "wr.json"),
      result: path.join(base, "dr.json"),
      packet: path.join(base, "pp.json"),
      manifest: path.join(base, "manifest.json"),
      response: path.join(base, "cc.json"),
      receipt: path.join(base, "r", "a-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.json"),
      transaction: path.join(base, "r", "t-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.json"),
    };
  }

  function queueDocument(missionId, revision) {
    return {
      schema_version: "tsf_canonical_queue_document_v1",
      compatibility_status: "GENERATED_EXECUTION_PACKET",
      durable_mission: { schema_version: "tsf_mission_envelope_v1", mission_id: missionId, mission_revision: revision, original_request: "DEMO FIXTURE" },
      source_binding: { durable_mission_id: missionId, durable_mission_revision: revision },
      model_resolution: route,
      mission_packet: {},
      role_extension: {},
      worker_instruction_packet: {},
    };
  }

  function preparation(missionId, revision, p, queuePath) {
    return {
      schema_version: "tsf_hq_dispatch_canonical_submission_result_v1",
      mission_id: missionId,
      mission_revision: revision,
      mission_path: p.mission,
      queue_record_path: queuePath,
      queue_result_path: p.queueResult,
      lifecycle_result_path: p.lifecycle,
      adapter_result_path: p.adapter,
      verifier_result_path: p.verifier,
      preservation_packet_path: p.packet,
      mission_sha256: fileHash(p.mission),
      queue_document_sha256: fileHash(p.queueRuntime),
      run_id: p.runId,
      route,
      access,
      fixture_behavior: "DETERMINISTIC_NOT_REAL_APP_SERVER",
    };
  }

  function completedOutcome(missionId, revision, naturalRequest = "Demo fixture") {
    const p = pathsFor(missionId, revision);
    const queuePath = path.join(queueRoot, "complete_ready_for_gate", `${missionId}.r${revision}.json`);
    const qd = queueDocument(missionId, revision);
    json(p.mission, { schema_version: "tsf_mission_envelope_v1", mission_id: missionId, mission_revision: revision, parent_mission_id: revision > 1 ? missionId : null, original_request: naturalRequest });
    json(p.queueRuntime, qd);
    json(queuePath, qd);
    const adapter = { mission_id: missionId, mission_revision: revision, run_id: p.runId, result_id: p.runId, thread_id: `demo-thread-${missionId}-r${revision}`, turn_id: `demo-turn-${missionId}-r${revision}`, observed_model: "DETERMINISTIC_FIXTURE_NO_MODEL", canonical_resolved_effort: "MEDIUM", child_exited: true, no_orphan_process: true, fixture_behavior: "NOT_REAL_APP_SERVER" };
    const workerResult = { mission_id: missionId, mission_revision: revision, files_touched: [], files_created: [], tests: [{ test_id: "hq-dispatch-demo-exact-response", status: "PASS" }], exact_response_evidence: { mission_id: missionId, mission_revision: revision, run_id: p.runId, result_id: p.runId, exact_response: "TSF_HQ_DISPATCH_DEMO_GREEN" } };
    const verifier = { mission_id: missionId, mission_revision: revision, verdict: "GREEN", verified: true, exact_response_evidence: { mission_id: missionId, mission_revision: revision, run_id: p.runId, result_id: p.runId } };
    const durableResult = { schema_version: "tsf_result_envelope_v1", mission_id: missionId, mission_revision: revision, result_id: p.runId, files_changed: [], tests: workerResult.tests, fixture_behavior: "DETERMINISTIC_NOT_REAL_APP_SERVER" };
    const admission = { schema_version: "tsf_admission_decision_v1", status: "ADMITTED_WITH_CAVEATS", mission_id: missionId, mission_revision: revision, result_id: p.runId, receipt_id: `demo-receipt-${hash(p.runId).slice(0, 16)}`, admission_receipt_path: p.receipt, queue_state_to: "complete_ready_for_gate", reasons: ["Deterministic TSF-local demo fixture admitted."], caveats: ["Fixture behavior; no real app-server, credential, plugin, or external network was used."] };
    const lifecycle = { schema_version: "tsf_lifecycle_terminal_result_v1", terminal_status: "COMPLETED_GREEN", final_decision: "GREEN", mission_id: missionId, mission_revision: revision, run_id: p.runId, result_id: p.runId, worker_launched: true, worker_status: "DETERMINISTIC_FIXTURE_GREEN", worker_result_path: p.worker, adapter_result_path: p.adapter, verifier_verdict: "GREEN", preservation_status: "PRESERVED", preservation_packet_file: p.packet, preservation_manifest_path: p.manifest, evidence_preserved: true };
    json(p.adapter, adapter); json(p.worker, workerResult); json(p.verifier, verifier); json(p.result, durableResult); json(p.packet, { mission_id: missionId, mission_revision: revision, result_id: p.runId, fixture: true }); json(p.manifest, { mission_id: missionId, mission_revision: revision, run_id: p.runId, fixture: true }); json(p.receipt, admission); json(p.transaction, { schema_version: "tsf_admission_transaction_v1", mission_id: missionId, mission_revision: revision, result_id: p.runId, admission_status: admission.status }); json(p.lifecycle, lifecycle);
    const queueResult = { schema_version: "tsf_canonical_queue_app_server_vertical_slice_result_v1", mission_id: missionId, mission_revision: revision, final_queue_state: "complete_ready_for_gate", durable_result_path: p.result, admission_receipt: admission, fixture_behavior: "DETERMINISTIC_NOT_REAL_APP_SERVER" };
    json(p.queueResult, queueResult);
    return { preparation: preparation(missionId, revision, p, queuePath), processResult: { code: 0, child_exited: true, stdout: "", stderr: "" }, queueResult, lifecycle, adapter, verifier, workerResult, durableResult, paths: p, queuePath };
  }

  function timOutcome(missionId, revision, naturalRequest) {
    const p = pathsFor(missionId, revision);
    const queuePath = path.join(queueRoot, "blocked_needs_tim", `${missionId}.r${revision}.json`);
    const qd = queueDocument(missionId, revision);
    json(p.mission, { schema_version: "tsf_mission_envelope_v1", mission_id: missionId, mission_revision: revision, parent_mission_id: null, original_request: naturalRequest });
    json(p.queueRuntime, qd); json(queuePath, qd); json(p.packet, { mission_id: missionId, mission_revision: revision, result_id: p.runId, final_decision: "TIM_REQUIRED" }); json(p.manifest, { mission_id: missionId, mission_revision: revision, run_id: p.runId, fixture: true });
    const request = {
      schema_version: "tsf_tim_required_request_v1",
      request_id: `timreq-${hash(`${missionId}:${revision}`).slice(0, 32)}`,
      request_kind: "CLARIFICATION_REQUIRED",
      mission_id: missionId,
      mission_revision: revision,
      run_id: p.runId,
      result_id: p.runId,
      repository: repositoryRoot,
      worktree: repositoryRoot,
      operation: "tsf_hq_dispatch_demo_clarification",
      exact_paths: ["fleet/control/policy-manifest.v1.json"],
      access_level: "READ_ONLY",
      network_scope: { network_policy: "PROHIBITED", control_plane_service_network_policy: "CODEX_SERVICE_ONLY", worker_tool_network_policy: "DISABLED" },
      surface: "CODEX",
      model: "DETERMINISTIC_FIXTURE_NO_MODEL",
      reason: "Demonstrate the Milestone 2B bounded response path without external service behavior.",
      question: "Confirm the deterministic TSF-local demo fixture response.",
      response_types: ["PROVIDE_CLARIFICATION"],
      expires_at: new Date(Date.now() + 30 * 60 * 1000).toISOString(),
      usage_limit: { max_uses: 1, reuse_policy: "SINGLE_USE" },
      authority_not_included: ["merge", "deployment", "production", "plugin", "credential"],
      original_run_terminal: true,
      worker_active: false,
      app_server_child_active: false,
      superseded: false,
      invalidated: false,
      answered: false,
    };
    const lifecycle = { schema_version: "tsf_lifecycle_terminal_result_v1", terminal_status: "TIM_REQUIRED", final_decision: "TIM_REQUIRED", mission_id: missionId, mission_revision: revision, run_id: p.runId, result_id: p.runId, worker_launched: false, worker_status: "NOT_RUN", adapter_result_path: "", verifier_verdict: "", preservation_status: "PRESERVED", preservation_packet_file: p.packet, preservation_manifest_path: p.manifest, evidence_preserved: true, blocked_reasons: [request.reason], tim_required_request: request };
    json(p.lifecycle, lifecycle);
    const queueResult = { mission_id: missionId, mission_revision: revision, final_decision: "TIM_REQUIRED_QUEUE_PREFLIGHT_BLOCKED", final_queue_state: "blocked_needs_tim", blocked_reasons: [request.reason] };
    json(p.queueResult, queueResult);
    return { preparation: preparation(missionId, revision, p, queuePath), processResult: { code: 1, child_exited: true, stdout: "", stderr: "TIM_REQUIRED" }, queueResult, lifecycle, adapter: null, verifier: null, workerResult: null, durableResult: null, paths: p, queuePath };
  }

  async function executionAdapter({ missionId, missionRevision, naturalRequest, recoveryParent }) {
    if (recoveryParent) return completedOutcome(missionId, missionRevision, naturalRequest);
    return /\bTIM(?:_|\s)REQUIRED\b/i.test(naturalRequest) ? timOutcome(missionId, missionRevision, naturalRequest) : completedOutcome(missionId, missionRevision, naturalRequest);
  }

  async function responseAdapter({ input, record }) {
    const p = pathsFor(input.mission_id, input.mission_revision);
    const responsePath = p.response;
    const targetRevision = input.response_type === "DENY_REQUEST" ? null : input.mission_revision + 1;
    const response = {
      schema_version: "tsf_hq_dispatch_tim_response_wrapper_result_v1",
      response_id: input.response_id,
      response_type: input.response_type,
      response_content_sha256: input.response_content_sha256,
      request_id: input.tim_required_request_id,
      response_record_path: responsePath,
      response_record_sha256: "",
      terminal_disposition: input.response_type === "DENY_REQUEST" ? "TIM_REQUIRED_DENIED" : "CLARIFICATION_RECORDED",
      approval: null,
      revision: targetRevision ? { mission_id: input.mission_id, mission_revision: targetRevision, run_id: `canonical-result-${input.mission_id}-${targetRevision}`, mission_path: pathsFor(input.mission_id, targetRevision).mission, queue_record_path: path.join(queueRoot, "complete_ready_for_gate", `${input.mission_id}.r${targetRevision}.json`) } : null,
      idempotent_replay: false,
      original_result_unchanged: true,
      worker_resumed: false,
      fixture_behavior: "DETERMINISTIC_NOT_REAL_APP_SERVER",
    };
    const canonicalResponse = { schema_version: "tsf_tim_required_response_v1", mission_id: input.mission_id, mission_revision: input.mission_revision, run_id: input.run_id, result_id: input.result_id, response_id: input.response_id, response_type: input.response_type, response_content_sha256: input.response_content_sha256, source_request: record.timCanonicalRequest, revision: response.revision, fixture_behavior: "DETERMINISTIC_NOT_REAL_APP_SERVER" };
    json(responsePath, canonicalResponse);
    response.response_record_sha256 = fileHash(responsePath);
    return { response, outcome: targetRevision ? completedOutcome(input.mission_id, targetRevision, record.naturalRequest) : null };
  }

  const manifestPath = path.join(fixtureRoot, "DEMO_MANIFEST.json");
  if (!existsSync(manifestPath)) json(manifestPath, { schema_version: "tsf_hq_dispatch_demo_manifest_v1", fixture_only: true, real_app_server_behavior: false, product_repository_required: false, plugin_required: false, credential_required: false, external_network_required: false, scenarios: ["MILESTONE_1_ROUTE_PREVIEW", "MILESTONE_2A_DETERMINISTIC_EXECUTION", "MILESTONE_2B_TIM_REQUIRED_RESPONSE"] });
  return { executionAdapter, responseAdapter, completedOutcome, timOutcome };
}

export function resetDemoFixtureRoot({ fixtureRoot, repositoryRoot }) {
  const expectedParent = path.resolve(repositoryRoot, ".codex-local", "fixtures");
  const target = path.resolve(fixtureRoot);
  if (!target.startsWith(`${expectedParent}${path.sep}`) || path.basename(target) !== "hq-dispatch-demo-v1") throw new Error("HQ_DEMO_RESET_CONTAINMENT_FAILED");
  if (existsSync(target)) rmSync(target, { recursive: true, force: true });
  return { reset_root: target, production_runtime_untouched: true, product_repository_untouched: true };
}
