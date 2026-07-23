import assert from "node:assert/strict";
import { createHash, randomUUID } from "node:crypto";
import { existsSync, readFileSync, rmSync } from "node:fs";
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(fileURLToPath(new URL("..", import.meta.url)));
const powershell = "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe";
const previewScript = path.join(root, "tools", "hq-dispatch", "v1", "Invoke-TsfHqDispatchRoutePreview.ps1");
const missionScript = path.join(root, "tools", "hq-dispatch", "v1", "New-TsfHqDispatchGovernedMission.ps1");
const fixtureRoot = path.join(root, ".codex-local", "fixtures", "hq-dispatch-exact-response-contract-v1");
const queueRoot = path.join(fixtureRoot, "queue");
rmSync(fixtureRoot, { recursive: true, force: true });

let assertions = 0;
function check(value, message) { assertions += 1; assert.ok(value, message); }
function equal(actual, expected, message) { assertions += 1; assert.equal(actual, expected, message); }
function sha256(value) { return createHash("sha256").update(value).digest("hex"); }
function json(file) { return JSON.parse(readFileSync(file, "utf8").replace(/^\uFEFF/, "")); }

function run(script, args, input) {
  return spawnSync(powershell, ["-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", script, ...args], {
    cwd: root,
    encoding: "utf8",
    input,
    maxBuffer: 8 * 1024 * 1024,
    windowsHide: true,
  });
}

function lastJson(result, label) {
  equal(result.status, 0, `${label} exits zero: ${result.stderr || result.stdout}`);
  return JSON.parse(result.stdout.trim().split(/\r?\n/).filter(Boolean).at(-1));
}

function preview(naturalRequest) {
  const result = run(previewScript, [], JSON.stringify({ natural_request: naturalRequest }));
  return { result, value: result.status === 0 ? JSON.parse(result.stdout.trim().split(/\r?\n/).at(-1)) : null };
}

function bindPreview(value) {
  const artifactPath = path.resolve(root, ...value.artifact.relative_path.split("/"));
  const artifactHash = sha256(readFileSync(artifactPath));
  const contract = value.exact_response_contract ? structuredClone(value.exact_response_contract) : null;
  if (contract) contract.preview_binding.preview_artifact_sha256 = artifactHash;
  return { artifactPath, artifactHash, contract };
}

let missionCounter = 0;
function prepare(naturalRequest, previewValue, mutate = (input) => input) {
  missionCounter += 1;
  const bound = bindPreview(previewValue);
  const input = mutate({
    mission_id: `exact-contract-${Date.now().toString(36)}-${process.pid}-${missionCounter}`,
    mission_revision: 1,
    natural_request: naturalRequest,
    preview_id: previewValue.preview_id,
    preview_sha256: bound.artifactHash,
    request_hash: sha256(naturalRequest),
    submission_id: `hq-submission-${randomUUID()}`,
    reviewed_exact_response_contract: bound.contract,
  });
  return run(missionScript, ["-TestOnlyQueueRoot", queueRoot, "-UnsupportedDevelopmentMode"], JSON.stringify(input));
}

try {
  const requiredLiteral = "TSF_V1_CANONICAL_FIRST_LAUNCH_GREEN";
  const requiredHash = "192168669db5ba0e1e6eb6877f2ce775defd0654a0fe4e124621aa7b9607c627";
  const naturalRequest = `Read only the TSF policy fixture and return exactly ${requiredLiteral}.`;
  const reviewed = preview(naturalRequest);
  equal(reviewed.result.status, 0, "exact response request produces a reviewed preview");
  equal(reviewed.value.result_validation_mode, "EXACT_LITERAL_V1", "preview selects EXACT_LITERAL_V1");
  equal(reviewed.value.exact_response_contract.expected_literal, requiredLiteral, "preview retains the requested literal");
  equal(reviewed.value.exact_response_contract.expected_literal_sha256, requiredHash, "preview retains the requested SHA-256");
  equal(reviewed.value.exact_response_contract.normalization_version, "ASCII_TOKEN_IDENTITY_V1", "preview records the normalization version");
  equal(reviewed.value.exact_response_contract.case_sensitive, true, "preview records case sensitivity");
  equal(reviewed.value.exact_response_contract.whitespace_sensitive, true, "preview records whitespace sensitivity");
  equal(reviewed.value.exact_response_contract.source_requirement.request_sha256, sha256(naturalRequest), "preview binds the source request identity");

  const prepared = lastJson(prepare(naturalRequest, reviewed.value), "exact contract mission preparation");
  const mission = json(prepared.mission_path);
  const queue = json(prepared.queue_record_path);
  equal(prepared.exact_response_contract.expected_literal_sha256, requiredHash, "submission result retains the contract");
  equal(mission.exact_response_contract.expected_literal, requiredLiteral, "mission retains the literal");
  equal(mission.exact_response_contract.mission_binding.mission_id, prepared.mission_id, "mission contract binds the allocated mission");
  equal(mission.exact_response_contract.mission_binding.mission_revision, 1, "mission contract binds the allocated revision");
  equal(queue.durable_mission.exact_response_contract.semantic_contract_sha256, mission.exact_response_contract.semantic_contract_sha256, "queue durable mission retains the semantic contract");
  equal(queue.mission_packet.exact_response_contract.expected_literal_sha256, requiredHash, "mission packet retains the exact hash");
  equal(queue.worker_instruction_packet.exact_response_contract.expected_literal, requiredLiteral, "worker instruction retains the exact literal");
  check(queue.worker_instruction_packet.exact_task.includes(`return exactly ${requiredLiteral}`), "worker task uses the reviewed literal");
  equal(queue.source_binding.exact_response_contract_sha256, sha256(JSON.stringify(mission.exact_response_contract)), "queue source binding hashes the mission contract");
  equal(mission.required_tests[0].command, `exact-response-sha256:${requiredHash}`, "required verifier test derives from the reviewed contract");
  equal(new Set([prepared.queue_record_path]).size, 1, "one canonical queue record represents the mission revision");

  check(prepare(naturalRequest, reviewed.value, (input) => { input.preview_sha256 = "0".repeat(64); return input; }).status !== 0, "stale preview artifact hash is rejected");
  check(prepare(naturalRequest, reviewed.value, (input) => { input.reviewed_exact_response_contract.expected_literal = "TSF_HQ_DISPATCH_READ_ONLY_GREEN"; return input; }).status !== 0, "substituted reviewed literal is rejected");
  check(prepare(naturalRequest, reviewed.value, (input) => { input.reviewed_exact_response_contract.expected_literal_sha256 = "0".repeat(64); return input; }).status !== 0, "changed reviewed literal hash is rejected");
  const second = preview(naturalRequest).value;
  check(prepare(naturalRequest, reviewed.value, (input) => { input.reviewed_exact_response_contract = bindPreview(second).contract; return input; }).status !== 0, "cross-preview contract substitution is rejected");
  check(prepare(`${naturalRequest} changed`, reviewed.value).status !== 0, "changed source request is rejected");
  check(prepare(naturalRequest, reviewed.value, (input) => { delete input.reviewed_exact_response_contract; return input; }).status !== 0, "partial preview binding is rejected even in an isolated test queue");

  for (const unsafe of [
    "Return exactly lower_case.",
    "Return exactly TWO SAFE TOKENS.",
    "Required exact response: TSF-V1-GREEN.",
    "Return exactly \"TSF_V1_GREEN\".",
  ]) check(preview(unsafe).result.status !== 0, `unsafe or ambiguous exact literal is rejected: ${unsafe}`);

  const oldLiteral = "TSF_HQ_DISPATCH_READ_ONLY_GREEN";
  const oldRequest = `Run the intentional M2A fixture and return exactly ${oldLiteral}.`;
  const oldPreview = preview(oldRequest);
  equal(oldPreview.result.status, 0, "intentional M2A exact fixture still previews");
  equal(oldPreview.value.exact_response_contract.expected_literal, oldLiteral, "M2A fixture retains only its reviewed old literal");
  const oldPrepared = lastJson(prepare(oldRequest, oldPreview.value), "intentional M2A contract preparation");
  equal(json(oldPrepared.mission_path).exact_response_contract.expected_literal, oldLiteral, "intentional M2A mission retains the old literal");

  const generalRequest = "Review bounded TSF local documentation.";
  const generalPreview = preview(generalRequest);
  equal(generalPreview.result.status, 0, "general request still previews");
  equal(generalPreview.value.result_validation_mode, "GENERAL_RESULT_V2", "general request uses mission-bound general validation");
  equal(generalPreview.value.exact_response_contract, null, "general request fabricates no exact literal");
  const generalPrepared = lastJson(prepare(generalRequest, generalPreview.value), "general result mission preparation");
  const generalMission = json(generalPrepared.mission_path);
  equal(generalMission.exact_response_contract, null, "general mission contains no exact-literal contract");
  check(!generalMission.normalized_goal.includes(oldLiteral), "general mission no longer receives the M2A fixture default");
  equal(generalMission.required_tests[0].test_id, "hq-dispatch-general-result-v2", "general mission uses its task-bound general result test");

  const uiHtml = readFileSync(path.join(root, "tools", "hq-dispatch", "v1", "public", "index.html"), "utf8");
  const uiScript = readFileSync(path.join(root, "tools", "hq-dispatch", "v1", "public", "app.js"), "utf8");
  check(uiHtml.includes("response-contract-preview") && uiHtml.includes("mission-response-contract"), "UI exposes reviewed validation and terminal response-truth surfaces");
  check(["requested_response", "response_contract", "exact_response", "verifier", "admission"].every((field) => uiScript.includes(field)), "UI projection renders requested, expected, observed, verifier, and admission truth");
} finally {
  if (existsSync(fixtureRoot)) rmSync(fixtureRoot, { recursive: true, force: true });
}

console.log(`HQ_DISPATCH_EXACT_RESPONSE_CONTRACT_PASS assertions=${assertions}`);
