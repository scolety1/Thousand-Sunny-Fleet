import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(fileURLToPath(new URL("..", import.meta.url)));
const powershell = "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe";
const fixtureRoot = path.join(root, ".codex-local", "fixtures", "hq-dispatch-m2b-contract");
const queueRoot = path.join(fixtureRoot, "queue");
const missionWrapper = path.join(root, "tools", "hq-dispatch", "v1", "New-TsfHqDispatchGovernedMission.ps1");
const responseWrapper = path.join(root, "tools", "hq-dispatch", "v1", "Invoke-TsfHqDispatchTimResponse.ps1");
const executor = path.join(root, "tools", "Invoke-TsfMissionQueueForegroundExecutor.ps1");
rmSync(fixtureRoot, { recursive: true, force: true });
const nonce = `${Date.now().toString(36)}-${process.pid}`;

let assertions = 0;
function check(value, message) { assertions += 1; assert.ok(value, message); }
function equal(actual, expected, message) { assertions += 1; assert.equal(actual, expected, message); }
function json(file) { return JSON.parse(readFileSync(file, "utf8").replace(/^\uFEFF/, "")); }
function fileHash(file) { return createHash("sha256").update(readFileSync(file)).digest("hex"); }

function runPowerShell(script, args = [], input = "") {
  return spawnSync(powershell, ["-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", script, ...args], {
    cwd: root,
    encoding: "utf8",
    input,
    maxBuffer: 4 * 1024 * 1024,
    windowsHide: true,
  });
}

function runPowerShellEncoded(source) {
  return spawnSync(powershell, ["-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-EncodedCommand", Buffer.from(source, "utf16le").toString("base64")], {
    cwd: root,
    encoding: "utf8",
    maxBuffer: 4 * 1024 * 1024,
    windowsHide: true,
  });
}

function lastJson(result, label) {
  equal(result.status, 0, `${label} exits zero: ${result.stderr || result.stdout}`);
  const line = result.stdout.trim().split(/\r?\n/).filter(Boolean).at(-1);
  return JSON.parse(line);
}

function responseHash(value) {
  const names = ["mission_id", "mission_revision", "run_id", "result_id", "tim_required_request_id", "request_evidence_sha256", "response_id", "response_type", "operator_confirmation", "response_payload"];
  const parts = names.map((name) => {
    const text = value[name] === null || value[name] === undefined ? "" : String(value[name]);
    return `${name}:${Buffer.byteLength(text, "utf8")}:${text}`;
  });
  return createHash("sha256").update(`${parts.join("\n")}\n`).digest("hex");
}

function prepareInitial(kind, suffix) {
  const missionId = `m2b-contract-${kind.toLowerCase()}-${suffix}-${nonce}`;
  const input = { mission_id: missionId, mission_revision: 1, natural_request: "Read only the TSF policy fixture and return the bounded exact response." };
  const prepared = lastJson(runPowerShell(missionWrapper, ["-TestOnlyQueueRoot", queueRoot, "-TestOnlyInitialTimKind", kind, "-UnsupportedDevelopmentMode"], JSON.stringify(input)), `${kind} preparation`);
  const oldHashBefore = fileHash(prepared.mission_path);
  const execution = runPowerShell(executor, ["-MissionPath", prepared.queue_record_path, "-QueueRoot", queueRoot, "-UnsupportedDevelopmentMode", "-TestOnlyAllowAlternateQueueRoot", "-TestOnlyNoWorkerLifecycle"]);
  equal(execution.status, 1, `${kind} initial lifecycle exits at terminal TIM_REQUIRED`);
  check(existsSync(prepared.lifecycle_result_path), `${kind} lifecycle writes a terminal result: ${execution.stderr || execution.stdout}`);
  const lifecycle = json(prepared.lifecycle_result_path);
  equal(lifecycle.terminal_status, "TIM_REQUIRED", `${kind} initial lifecycle is canonical TIM_REQUIRED`);
  equal(lifecycle.worker_launched, false, `${kind} initial lifecycle launches no worker`);
  check(existsSync(path.join(queueRoot, "blocked_needs_tim", `${missionId}.r1.json`)), `${kind} original queue record is terminal blocked_needs_tim`);
  return { missionId, prepared, lifecycle, lifecycleHash: fileHash(prepared.lifecycle_result_path), oldMissionHash: oldHashBefore };
}

let responseCounter = 0;
function buildResponse(source, type, payload = null, override = {}) {
  responseCounter += 1;
  const value = {
    mission_id: source.missionId,
    mission_revision: 1,
    run_id: source.lifecycle.run_id,
    result_id: source.lifecycle.result_id,
    tim_required_request_id: source.lifecycle.tim_required_request.request_id,
    request_evidence_sha256: source.lifecycleHash,
    response_id: `hq-response-contract-20260715-${String(responseCounter).padStart(4, "0")}`,
    response_type: type,
    operator_confirmation: { APPROVE_EXACT_REQUEST: "APPROVE EXACT REQUEST", DENY_REQUEST: "DENY REQUEST", PROVIDE_CLARIFICATION: "PROVIDE CLARIFICATION" }[type],
    response_payload: payload,
    ...override,
  };
  value.response_content_sha256 = responseHash(value);
  return value;
}

function invokeResponse(value) {
  return runPowerShell(responseWrapper, ["-TestOnlyQueueRoot", queueRoot], JSON.stringify(value));
}

function prepareRevision(source, response) {
  const input = {
    mission_id: source.missionId,
    mission_revision: 2,
    parent_mission_revision: 1,
    source_result_id: source.lifecycle.result_id,
    tim_required_request_id: source.lifecycle.tim_required_request.request_id,
    response_id: response.response_id,
    response_record_sha256: response.response_record_sha256,
  };
  return lastJson(runPowerShell(missionWrapper, ["-TestOnlyQueueRoot", queueRoot, "-UnsupportedDevelopmentMode"], JSON.stringify(input)), "governed revision preparation");
}

const requestSchema = json(path.join(root, "fleet", "control", "tim-required-request.schema.v1.json"));
const responseSchema = json(path.join(root, "fleet", "control", "tim-required-response.schema.v1.json"));
equal(requestSchema.additionalProperties, false, "TIM request contract is closed");
equal(responseSchema.additionalProperties, false, "TIM response record contract is closed");

const approval = prepareInitial("APPROVAL", "approval-0001");
equal(approval.lifecycle.tim_required_request.request_kind, "APPROVAL_REQUIRED", "approval request kind is exact");
equal(approval.lifecycle.tim_required_request.operation, "tsf_hq_dispatch_safe_fixture_execution", "approval request operation is canonical");
equal(approval.lifecycle.tim_required_request.response_types.join("|"), "APPROVE_EXACT_REQUEST|DENY_REQUEST", "approval request exposes only compatible types");
const approvalInput = buildResponse(approval, "APPROVE_EXACT_REQUEST");
const approvalOutcome = lastJson(invokeResponse(approvalInput), "exact approval response");
equal(approvalOutcome.terminal_disposition, "EXACT_APPROVAL_RELAYED", "exact approval is relayed");
equal(approvalOutcome.worker_resumed, false, "approval does not resume original worker");
equal(approvalOutcome.original_result_unchanged, true, "approval preserves original result bytes");
const approvalLedger = json(approvalOutcome.approval.ledger_path);
equal(approvalLedger.approvals.length, 1, "one canonical approval record exists");
const approvalRecord = approvalLedger.approvals[0];
equal(approvalRecord.request_id, approval.lifecycle.tim_required_request.request_id, "approval binds exact request id");
equal(approvalRecord.request_evidence_sha256, approval.lifecycleHash, "approval binds exact evidence hash");
equal(approvalRecord.allowed_files_or_paths.join("|"), approval.lifecycle.tim_required_request.exact_paths.join("|"), "approval paths are exact");
equal(approvalRecord.max_uses, 1, "approval usage is single-use");
equal(approvalRecord.reuse_policy, "SINGLE_USE", "approval automatic reuse is prohibited");
equal(approvalRecord.authorized_mission_revision, 2, "approval authorizes only the new revision");
const approvalReplay = lastJson(invokeResponse(approvalInput), "exact approval replay");
equal(approvalReplay.idempotent_replay, true, "exact approval replay is idempotent");
equal(json(approvalOutcome.approval.ledger_path).approvals.length, 1, "exact replay creates no second approval");
const changedApproval = { ...approvalInput, operator_confirmation: "DENY REQUEST", response_type: "DENY_REQUEST" };
changedApproval.response_content_sha256 = responseHash(changedApproval);
check(invokeResponse(changedApproval).status !== 0, "changed replay under one response id fails closed");

for (const field of ["approval_ledger_path", "queue_root", "evidence_root", "new_mission_id", "mission_envelope", "expires_at", "exact_paths", "access_level", "network_scope", "model", "reasoning_effort", "verifier_result", "admission_result", "authority_grants", "command", "script", "executable", "environment"]) {
  const candidate = { ...approvalInput, [field]: field === "exact_paths" ? [".."] : "caller-supplied" };
  check(invokeResponse(candidate).status !== 0, `caller authority field ${field} is rejected`);
}
for (const [field, value] of [["mission_revision", 9], ["run_id", "wrong-run"], ["result_id", "wrong-result"], ["tim_required_request_id", "timreq-00000000000000000000000000000000"], ["request_evidence_sha256", "0".repeat(64)]]) {
  const candidate = { ...approvalInput, [field]: value };
  candidate.response_id = `hq-response-binding-${field.replaceAll("_", "-")}-0001`;
  candidate.response_content_sha256 = responseHash(candidate);
  check(invokeResponse(candidate).status !== 0, `wrong ${field} binding is rejected`);
}

const approvedRevision = prepareRevision(approval, approvalOutcome);
equal(approvedRevision.mission_revision, 2, "approval creates revision two");
equal(approvedRevision.run_id, `canonical-result-${approval.missionId}-2`, "approval revision has a new run identity");
check(existsSync(approvedRevision.queue_record_path), "approval revision creates a new queue document");
const approvedMission = json(approvedRevision.mission_path);
const approvedQueue = json(approvedRevision.queue_record_path);
const approvedKernelMission = JSON.parse(JSON.stringify(approvedQueue.mission_packet));
approvedKernelMission.role_extension = approvedQueue.role_extension;
approvedKernelMission.durable_source_binding = approvedQueue.source_binding;
approvedKernelMission.model_resolution = approvedQueue.model_resolution;
approvedKernelMission.worker_instruction_contract = approvedQueue.worker_instruction_packet;
equal(approvedMission.parent_mission_id, approval.missionId, "approval revision links its canonical parent");
equal(approvedMission.approval_references[0].approval_id, approvalRecord.approval_id, "approval revision references exact approval id");
equal(approvedMission.revision_context.supersedes_result_id, approval.lifecycle.result_id, "approval revision links original terminal result");
equal(fileHash(approval.prepared.lifecycle_result_path), approval.lifecycleHash, "original approval TIM result remains immutable");
const approvedRevisionReplay = prepareRevision(approval, approvalOutcome);
equal(approvedRevisionReplay.idempotent_replay, true, "revision and queue replay are idempotent");
equal(approvedRevisionReplay.queue_document_sha256, approvedRevision.queue_document_sha256, "revision replay returns exact queue identity");

const matcherRoot = path.join(fixtureRoot, "matcher-negatives");
mkdirSync(matcherRoot, { recursive: true });
function matcherProbe(label, mutateLedger = () => {}, mutateMission = () => {}) {
  const ledger = JSON.parse(JSON.stringify(approvalLedger));
  const mission = JSON.parse(JSON.stringify(approvedKernelMission));
  mutateLedger(ledger);
  mutateMission(mission);
  const ledgerPath = path.join(matcherRoot, `${label}.ledger.json`);
  const missionPath = path.join(matcherRoot, `${label}.mission.json`);
  writeFileSync(ledgerPath, JSON.stringify(ledger), "utf8");
  writeFileSync(missionPath, JSON.stringify(mission), "utf8");
  const quote = (value) => value.replaceAll("'", "''");
  const source = `$ErrorActionPreference='Stop'; . '${quote(path.join(root, "tools", "codex-fleet-enforcement-kernel.ps1"))}'; $m=Get-Content -Raw -LiteralPath '${quote(missionPath)}'|ConvertFrom-Json; $l=Get-Content -Raw -LiteralPath '${quote(ledgerPath)}'|ConvertFrom-Json; $r=@(Find-TsfKernelApprovalMatches -Mission $m -Ledger $l -LedgerPath '${quote(ledgerPath)}' -RequireCanonicalUsageBinding); [pscustomobject]@{matches=@($r)}|ConvertTo-Json -Depth 20 -Compress`;
  const result = lastJson(runPowerShellEncoded(source), `${label} direct canonical matcher probe`);
  equal(result.matches.length, 1, `${label} matcher returns one requirement result`);
  equal(result.matches[0].satisfied, false, `${label} matcher rejects mutated authority`);
  check(result.matches[0].match_status !== "MATCHED_ACTIVE_APPROVAL", `${label} cannot match active approval`);
}

matcherProbe("different-operation", (ledger) => { ledger.approvals[0].exact_action = "different_operation"; });
matcherProbe("wrong-repository", (ledger) => { ledger.approvals[0].repo_path = path.join(root, "wrong-repository"); });
matcherProbe("wrong-worktree", (ledger) => { ledger.approvals[0].worktree_path = path.join(root, "wrong-worktree"); });
matcherProbe("extra-path", (ledger) => { ledger.approvals[0].allowed_files_or_paths.push("fleet/control/mission-envelope.schema.v1.json"); });
matcherProbe("altered-reuse", (ledger) => { ledger.approvals[0].reuse_policy = "MULTI_USE"; ledger.approvals[0].max_uses = 2; });
matcherProbe("cross-mission", () => {}, (mission) => { mission.mission_id = "cross-mission-binding-0001"; });

const mutatedWriterRequest = JSON.parse(JSON.stringify(approval.lifecycle.tim_required_request));
mutatedWriterRequest.operation = "different_operation";
const mutatedWriterRequestPath = path.join(matcherRoot, "mutated-writer-request.json");
writeFileSync(mutatedWriterRequestPath, JSON.stringify(mutatedWriterRequest), "utf8");
const writerQuote = (value) => value.replaceAll("'", "''");
const writerSource = `$ErrorActionPreference='Stop'; . '${writerQuote(path.join(root, "tools", "codex-fleet-enforcement-kernel.ps1"))}'; $r=Get-Content -Raw -LiteralPath '${writerQuote(mutatedWriterRequestPath)}'|ConvertFrom-Json; New-TsfKernelExactApprovalLedger -Request $r -RequestEvidencePath '${writerQuote(approval.prepared.lifecycle_result_path)}' -RequestEvidenceSha256 '${approval.lifecycleHash}' -ResponseId 'hq-response-writer-negative-20260715-0001' -ResponseContentSha256 '${"1".repeat(64)}' -AuthorizedMissionRevision 2 | Out-Null`;
check(runPowerShellEncoded(writerSource).status !== 0, "canonical writer rejects a request object changed from its exact evidence");

const approvalExecution = runPowerShell(executor, ["-MissionPath", approvedRevision.queue_record_path, "-QueueRoot", queueRoot, "-ApprovalLedgerPath", approvalOutcome.approval.ledger_path, "-UnsupportedDevelopmentMode", "-TestOnlyAllowAlternateQueueRoot", "-TestOnlyNoWorkerLifecycle"]);
equal(approvalExecution.status, 1, "test-only no-worker revision stops without fabricating admission");
const approvedLifecycle = json(approvedRevision.lifecycle_result_path);
equal(approvedLifecycle.preflight_approved, true, "new approval revision passes canonical matcher and preflight");
equal(approvedLifecycle.worker_launched, false, "test-only approval proof launches no worker");
const consumedLedger = json(approvalOutcome.approval.ledger_path);
equal(consumedLedger.approvals[0].usage_count, 1, "canonical approval is consumed exactly once");
equal(consumedLedger.approvals[0].consumed_by_run_id, approvedRevision.run_id, "approval consumption binds the new run");
equal(consumedLedger.approvals[0].state, "EXHAUSTED", "single-use approval is exhausted after consumption");

const denial = prepareInitial("APPROVAL", "denial-0001");
const denialInput = buildResponse(denial, "DENY_REQUEST", "Operator denies this bounded request.");
const denialOutcome = lastJson(invokeResponse(denialInput), "denial response");
equal(denialOutcome.terminal_disposition, "TIM_REQUIRED_DENIED", "denial is terminal and explicit");
equal(denialOutcome.approval, null, "denial creates no approval");
equal(denialOutcome.revision, null, "denial creates no revision");
equal(denialOutcome.worker_resumed, false, "denial starts no worker");
check(!existsSync(path.join(queueRoot, "inbox", `${denial.missionId}.r2.json`)), "denial creates no queue document");
equal(fileHash(denial.prepared.lifecycle_result_path), denial.lifecycleHash, "denial preserves original result");
equal(lastJson(invokeResponse(denialInput), "denial replay").idempotent_replay, true, "exact denial replay is idempotent");
const changedDenial = { ...denialInput, response_payload: "Changed denial reason." };
changedDenial.response_content_sha256 = responseHash(changedDenial);
check(invokeResponse(changedDenial).status !== 0, "changed denial replay fails closed");

const clarification = prepareInitial("CLARIFICATION", "clarification-0001");
equal(clarification.lifecycle.tim_required_request.request_kind, "CLARIFICATION_REQUIRED", "clarification request kind is exact");
equal(clarification.lifecycle.tim_required_request.response_types.join("|"), "PROVIDE_CLARIFICATION", "clarification request accepts one response type");
check(clarification.lifecycle.tim_required_request.question.includes("policy-manifest"), "canonical bounded question is present");
const clarificationInput = buildResponse(clarification, "PROVIDE_CLARIFICATION", "Proceed with only the bounded TSF-local read-only policy manifest fixture.");
const clarificationOutcome = lastJson(invokeResponse(clarificationInput), "clarification response");
equal(clarificationOutcome.terminal_disposition, "CLARIFICATION_RECORDED", "clarification record persists canonically");
equal(clarificationOutcome.worker_resumed, false, "clarification does not resume original worker");
const clarifiedRevision = prepareRevision(clarification, clarificationOutcome);
const clarifiedMission = json(clarifiedRevision.mission_path);
equal(clarifiedMission.original_request, json(clarification.prepared.mission_path).original_request, "original mission request is preserved");
equal(clarifiedMission.clarification_references[0].response_id, clarificationInput.response_id, "new revision links exact clarification response");
equal(clarifiedMission.revision_context.route_classification, "SAFE_LOCAL_MISSION", "Project Main Bot reroutes bounded clarification");
equal(clarifiedMission.approval_requirements.length, 0, "bounded authority-neutral clarification needs no new approval");
check(clarifiedRevision.run_id !== clarification.lifecycle.run_id, "clarification revision uses a new run identity");
check(clarifiedRevision.lifecycle_result_path !== clarification.prepared.lifecycle_result_path, "clarification revision uses a new result path");
equal(fileHash(clarification.prepared.lifecycle_result_path), clarification.lifecycleHash, "original clarification TIM result remains immutable");
const clarificationExecution = runPowerShell(executor, ["-MissionPath", clarifiedRevision.queue_record_path, "-QueueRoot", queueRoot, "-UnsupportedDevelopmentMode", "-TestOnlyAllowAlternateQueueRoot", "-TestOnlyNoWorkerLifecycle"]);
equal(clarificationExecution.status, 1, "test-only clarification revision stops without fabricated admission");
equal(json(clarifiedRevision.lifecycle_result_path).preflight_approved, true, "clarified revision independently reruns and passes preflight");

const secretClarification = prepareInitial("CLARIFICATION", "secret-0001");
const secretInput = buildResponse(secretClarification, "PROVIDE_CLARIFICATION", "api_key=abcdefghijklmnopqrstuvwxyz123456");
check(invokeResponse(secretInput).status !== 0, "secret-like clarification is rejected");
const oversizedInput = buildResponse(secretClarification, "PROVIDE_CLARIFICATION", "x".repeat(2001), { response_id: "hq-response-oversized-20260715-0001" });
oversizedInput.response_content_sha256 = responseHash(oversizedInput);
check(invokeResponse(oversizedInput).status !== 0, "oversized clarification is rejected");

const routeChange = prepareInitial("CLARIFICATION", "route-change-0001");
const routeChangeInput = buildResponse(routeChange, "PROVIDE_CLARIFICATION", "The revised interpretation includes an API boundary for review only.");
const routeChangeOutcome = lastJson(invokeResponse(routeChangeInput), "authority-relevant clarification response");
const routeChangeRevision = prepareRevision(routeChange, routeChangeOutcome);
const routeChangeMission = json(routeChangeRevision.mission_path);
equal(routeChangeMission.revision_context.authority_relevant_change, true, "authority-relevant clarification is detected");
equal(routeChangeMission.approval_requirements.length, 1, "authority-relevant route change requires fresh approval");
const routeExecution = runPowerShell(executor, ["-MissionPath", routeChangeRevision.queue_record_path, "-QueueRoot", queueRoot, "-UnsupportedDevelopmentMode", "-TestOnlyAllowAlternateQueueRoot", "-TestOnlyNoWorkerLifecycle"]);
equal(routeExecution.status, 1, "changed route stops before worker");
const routeLifecycle = json(routeChangeRevision.lifecycle_result_path);
equal(routeLifecycle.terminal_status, "TIM_REQUIRED", "changed route produces a fresh canonical TIM_REQUIRED result");
equal(routeLifecycle.tim_required_request.request_kind, "APPROVAL_REQUIRED", "changed route produces a fresh approval request");
check(routeLifecycle.tim_required_request.request_id !== routeChange.lifecycle.tim_required_request.request_id, "fresh approval request cannot reuse clarification request identity");
equal(routeLifecycle.worker_launched, false, "authority-relevant route launches no worker before fresh approval");

console.log(JSON.stringify({ schema_version: "tsf_hq_dispatch_tim_relay_canonical_test_v1", assertions, status: "PASS", approval_id: approvalRecord.approval_id, denial_response_id: denialInput.response_id, clarification_response_id: clarificationInput.response_id, old_run_id: clarification.lifecycle.run_id, new_run_id: clarifiedRevision.run_id }));
