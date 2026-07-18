import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { reconcileCanonicalState, runDoctor } from "../tools/hq-dispatch/v1/reliability.mjs";

const root = path.resolve(fileURLToPath(new URL("..", import.meta.url)));
const queueRoot = path.join(root, "fleet", "missions");
const runtimeRoot = path.join(root, ".codex-local", "fixtures", "runtime-queue-cleanliness-v1", "runtime");
const fixtureRoot = path.join(root, ".codex-local", "fixtures", "runtime-queue-cleanliness-v1");
const generator = path.join(root, "tests", "support", "New-TsfCanonicalQueueTestRecords.ps1");
const validator = path.join(root, "tools", "hq-dispatch", "v1", "Test-TsfHqDispatchCanonicalQueueRecordsV1.ps1");
const stopScript = path.join(root, "tools", "hq-dispatch", "v1", "Stop-TsfHqDispatchV1.ps1");
const powershell = "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe";
const sentinel = path.join(root, "tests", ".tsf-runtime-cleanliness-sentinel.tmp");
const trackedPlaceholder = path.join(queueRoot, "complete_ready_for_gate", ".gitkeep");
const trackedOriginal = readFileSync(trackedPlaceholder);
const created = [];
const createdLinks = [];
let assertions = 0;

function check(value, message) { assertions += 1; assert.ok(value, message); }
function equal(actual, expected, message) { assertions += 1; assert.equal(actual, expected, message); }
function sha256(value) { return createHash("sha256").update(value).digest("hex"); }
function git(args) { return execFileSync("git.exe", ["-C", root, ...args], { encoding: "utf8", windowsHide: true }).trim(); }
function clone(value) { return JSON.parse(JSON.stringify(value)); }
function writeJson(file, value) { mkdirSync(path.dirname(file), { recursive: true }); writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`, "utf8"); created.push(file); }
function writeRaw(file, value) { mkdirSync(path.dirname(file), { recursive: true }); writeFileSync(file, value, "utf8"); created.push(file); }
function generate(descriptors) {
  const result = spawnSync(powershell, ["-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", generator, "-RepositoryRoot", root], {
    cwd: root, input: JSON.stringify(descriptors), encoding: "utf8", windowsHide: true, timeout: 120000, maxBuffer: 16 * 1024 * 1024,
  });
  if (result.status !== 0) throw new Error(`CANONICAL_TEST_RECORD_GENERATION_FAILED:${result.stderr}`);
  const parsed = JSON.parse(String(result.stdout).replace(/^\uFEFF/, ""));
  const rows = Array.isArray(parsed) ? parsed : [parsed];
  for (const row of rows) created.push(row.path);
  return rows;
}
function validateDirect(descriptors) {
  const result = spawnSync(powershell, ["-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", validator, "-RepositoryRoot", root, "-QueueRoot", queueRoot], {
    cwd: root, input: JSON.stringify(descriptors), encoding: "utf8", windowsHide: true, timeout: 120000, maxBuffer: 16 * 1024 * 1024,
  });
  if (result.status !== 0) throw new Error(`CANONICAL_QUEUE_VALIDATOR_PROCESS_FAILED:${result.stderr}`);
  const parsed = JSON.parse(String(result.stdout).replace(/^\uFEFF/, ""));
  return Array.isArray(parsed) ? parsed : [parsed];
}
function errorsFor(reconciliation, file) {
  const expected = path.resolve(file).toLowerCase();
  return reconciliation.parse_errors.filter((item) => path.resolve(item.path).toLowerCase() === expected);
}
function doctorRuntimePolicy(doctor) { return doctor.checks.find((item) => item.id === "runtime_queue_evidence_policy"); }

const matrix = [
  ["QUEUED", "inbox"],
  ["RUNNING", "worker_running"],
  ["TIM_REQUIRED", "blocked_needs_tim"],
  ["ADMITTED", "complete_ready_for_gate"],
  ["REJECTED", "complete_review_only"],
  ["INTERRUPTED", "stopped"],
  ["RECOVERED", "complete_ready_for_gate"],
  ["EXACT_REPLAY", "complete_ready_for_gate"],
];

try {
  mkdirSync(runtimeRoot, { recursive: true });
  const descriptors = matrix.map(([outcome, state], index) => {
    const missionId = `doctor-${outcome.toLowerCase().replaceAll("_", "-")}-${process.pid}-${index}`;
    return { outcome, state, mission_id: missionId, mission_revision: 1, path: path.join(queueRoot, state, `${missionId}.r1.json`) };
  });
  const generated = generate(descriptors);
  equal(generated.length, matrix.length, "canonical generator creates every valid-state fixture through the production translator");
  for (const row of generated) {
    check(existsSync(row.path), "complete canonical generated record exists");
    equal(sha256(readFileSync(row.path)), row.sha256, "generated record hash is observed from disk");
    equal(git(["status", "--short", "--untracked-files=all", "--", path.relative(root, row.path)]), "", "valid generated record is narrowly ignored by Git");
  }

  const accepted = reconcileCanonicalState({ runtimeRoot, queueRoot });
  equal(accepted.safe_to_reconcile, true, "complete canonical records pass reconciliation");
  equal(accepted.queue_inventory.unknown_or_invalid_count, 0, "canonical validator reports no invalid generated record");
  check(accepted.queue_inventory.generated_record_count >= matrix.length, "Doctor inventories every valid generated record");
  for (const descriptor of descriptors) check(accepted.items.some((item) => item.mission_id === descriptor.mission_id && item.last_known_queue_state === descriptor.state), `${descriptor.outcome} state remains visible to reconciliation`);
  const acceptedDoctor = runDoctor({ runtimeRoot, queueRoot, allowDirtyForTest: true });
  equal(doctorRuntimePolicy(acceptedDoctor).status, "GREEN", "Doctor accepts only records approved by the canonical queue validator");
  equal(doctorRuntimePolicy(acceptedDoctor).evidence.generated_record_count >= matrix.length, true, "Doctor reports generated record count and root");

  const replayBefore = accepted.items.find((item) => item.mission_id === descriptors[7].mission_id);
  const replayAfter = reconcileCanonicalState({ runtimeRoot, queueRoot }).items.find((item) => item.mission_id === descriptors[7].mission_id);
  equal(replayAfter.evidence_hash, replayBefore.evidence_hash, "exact replay inspection is idempotent");
  equal(sha256(readFileSync(descriptors[7].path)), generated[7].sha256, "exact replay inspection leaves canonical bytes unchanged");

  const baseDocument = JSON.parse(readFileSync(descriptors[0].path, "utf8"));
  const invalid = [];
  const addInvalid = (name, value, raw = false, state = "archived") => {
    const file = path.join(queueRoot, state, `${name}.r1.json`);
    if (raw) writeRaw(file, value); else writeJson(file, value);
    invalid.push(file);
    return file;
  };
  addInvalid(`minimal-${process.pid}`, { mission_id: `minimal-${process.pid}`, mission_revision: 1 });
  addInvalid(`empty-object-${process.pid}`, {});
  const noSchema = clone(baseDocument); delete noSchema.schema_version; addInvalid(`missing-schema-${process.pid}`, noSchema);
  const noPacket = clone(baseDocument); delete noPacket.mission_packet; addInvalid(`missing-packet-${process.pid}`, noPacket);
  const noIntegrity = clone(baseDocument); delete noIntegrity.source_binding.mission_packet_sha256; addInvalid(`missing-integrity-${process.pid}`, noIntegrity);
  addInvalid(`malformed-${process.pid}`, "{not-json\n", true);
  const wrongSchema = clone(baseDocument); wrongSchema.schema_version = "tsf_canonical_queue_document_v999"; addInvalid(`wrong-schema-${process.pid}`, wrongSchema);
  addInvalid(`unknown-ignored-${process.pid}`, { arbitrary: "ignored filename must not grant trust" });
  addInvalid(`filename-mismatch-${process.pid}`, baseDocument);
  const revisionMismatch = clone(baseDocument); revisionMismatch.durable_mission.mission_revision = 2; revisionMismatch.source_binding.durable_mission_revision = 2; addInvalid(`revision-mismatch-${process.pid}`, revisionMismatch);
  const alternateCase = JSON.parse(readFileSync(descriptors[1].path, "utf8")); addInvalid(alternateCase.durable_mission.mission_id.toUpperCase(), alternateCase);
  const wrongStateFile = path.join(queueRoot, "completed", `wrong-state-${process.pid}.r1.json`); writeJson(wrongStateFile, baseDocument); invalid.push(wrongStateFile);

  const duplicatePath = path.join(queueRoot, "archived", path.basename(descriptors[0].path));
  writeRaw(duplicatePath, readFileSync(descriptors[0].path, "utf8"));
  invalid.push(duplicatePath);
  const rejected = reconcileCanonicalState({ runtimeRoot, queueRoot });
  equal(rejected.safe_to_reconcile, false, "adversarial queue documents make reconciliation unsafe");
  for (const file of invalid.filter((file) => file !== duplicatePath)) check(errorsFor(rejected, file).length > 0, `Doctor reports the exact rejected protected path: ${path.basename(file)}`);
  check(errorsFor(rejected, invalid[0]).some((item) => JSON.stringify(item).includes("CANONICAL_QUEUE_DOCUMENT_REJECTED")), "filename-shaped identity-only JSON is rejected by canonical validation");
  check(rejected.parse_errors.some((item) => JSON.stringify(item).includes("DUPLICATE_QUEUE_MISSION_REVISION") && [duplicatePath, descriptors[0].path].some((candidate) => path.resolve(candidate).toLowerCase() === path.resolve(item.path).toLowerCase())), `duplicate mission revision is rejected regardless of enumeration order: ${JSON.stringify(rejected.parse_errors)}`);
  equal(doctorRuntimePolicy(runDoctor({ runtimeRoot, queueRoot, allowDirtyForTest: true })).status, "UNSAFE_TO_START", "Doctor fails closed while any invalid protected record exists");

  const missingState = validateDirect([{ path: descriptors[0].path, state: "", mission_id: descriptors[0].mission_id, mission_revision: 1 }])[0];
  equal(missingState.valid, false, "canonical file validator rejects a missing queue-state binding");
  check(missingState.errors.includes("QUEUE_RECORD_STATE_NOT_CANONICAL"), "missing state has an exact fail-closed disposition");
  const mismatchedState = validateDirect([{ path: descriptors[0].path, state: "approved_for_worker", mission_id: descriptors[0].mission_id, mission_revision: 1 }])[0];
  equal(mismatchedState.valid, false, "canonical file validator rejects directory/state mismatch");
  check(mismatchedState.errors.includes("QUEUE_RECORD_DIRECTORY_STATE_MISMATCH"), "wrong directory/state has an exact fail-closed disposition");

  for (const file of invalid) rmSync(file, { force: true });
  invalid.length = 0;
  equal(reconcileCanonicalState({ runtimeRoot, queueRoot }).safe_to_reconcile, true, "removing only adversarial fixtures restores queue safety");

  const linkTargetDir = path.join(fixtureRoot, "link-targets");
  const validLinkMission = `link-valid-${process.pid}`;
  const validTarget = path.join(linkTargetDir, `${validLinkMission}.r1.json`);
  generate([{ outcome: "SYMLINK_TARGET", state: "archived", mission_id: validLinkMission, mission_revision: 1, path: validTarget }]);
  const outsideTarget = path.join(fixtureRoot, "outside-target.txt"); writeRaw(outsideTarget, "outside target must remain unchanged\n");
  const otherWorktreeTarget = path.join("C:\\TSF_HOTFIX2_PROOF", "fleet", "control", "policy-manifest.v1.json");
  const targetHashes = new Map([[validTarget, sha256(readFileSync(validTarget))], [outsideTarget, sha256(readFileSync(outsideTarget))], [otherWorktreeTarget, sha256(readFileSync(otherWorktreeTarget))]]);
  const linkCases = [
    [validTarget, path.join(queueRoot, "archived", `${validLinkMission}.r1.json`), "valid canonical record"],
    [outsideTarget, path.join(queueRoot, "archived", `link-outside-${process.pid}.r1.json`), "outside file"],
    [otherWorktreeTarget, path.join(queueRoot, "archived", `link-worktree-${process.pid}.r1.json`), "another worktree"],
  ];
  let realSymlinkCases = 0;
  for (const [target, link, label] of linkCases) {
    try { symlinkSync(target, link, "file"); createdLinks.push(link); realSymlinkCases += 1; }
    catch (error) { check(["EPERM", "EACCES", "UNKNOWN"].includes(error.code), `${label} symlink creation is explicitly privilege-limited when unsupported`); }
  }
  const junctionTarget = path.join(fixtureRoot, "junction-target"); mkdirSync(junctionTarget, { recursive: true }); writeFileSync(path.join(junctionTarget, "target.txt"), "junction target\n", "utf8");
  const junction = path.join(queueRoot, "archived", `junction-${process.pid}`);
  let realJunction = false;
  try { symlinkSync(junctionTarget, junction, "junction"); createdLinks.push(junction); realJunction = true; }
  catch (error) { check(["EPERM", "EACCES", "UNKNOWN"].includes(error.code), "junction creation is explicitly platform-limited when unsupported"); }
  check(realSymlinkCases > 0 || realJunction, "at least one real Windows link/reparse branch is exercised");
  const linked = reconcileCanonicalState({ runtimeRoot, queueRoot });
  equal(linked.safe_to_reconcile, false, "link or reparse entry makes reconciliation unsafe without following its target");
  for (const link of createdLinks) check(errorsFor(linked, link).some((item) => JSON.stringify(item).includes("REPARSE_POINT_REJECTED")), `Doctor rejects link/reparse entry: ${path.basename(link)}`);
  for (const [target, hash] of targetHashes) equal(sha256(readFileSync(target)), hash, "rejected link target remains byte-identical");
  for (const link of createdLinks.splice(0)) rmSync(link, { force: true, recursive: false });
  equal(reconcileCanonicalState({ runtimeRoot, queueRoot }).safe_to_reconcile, true, "removing only test-owned links restores queue safety");

  writeFileSync(sentinel, "unrelated source dirtiness sentinel\n", "utf8");
  const untrackedDoctor = runDoctor({ runtimeRoot, queueRoot });
  check(untrackedDoctor.repository.status_lines.some((line) => line.includes("tests/.tsf-runtime-cleanliness-sentinel.tmp")), "Doctor reports the exact unrelated untracked source path");
  equal(untrackedDoctor.safe_to_start, false, "unrelated untracked source file remains unsafe");
  rmSync(sentinel, { force: true });

  writeFileSync(trackedPlaceholder, Buffer.concat([trackedOriginal, Buffer.from("tracked modification sentinel\n")]));
  const trackedDoctor = runDoctor({ runtimeRoot, queueRoot });
  check(trackedDoctor.repository.status_lines.some((line) => line.includes("fleet/missions/complete_ready_for_gate/.gitkeep")), "Doctor reports the exact tracked source modification");
  equal(trackedDoctor.safe_to_start, false, "tracked source modification remains unsafe");
  execFileSync("git.exe", ["-C", root, "add", "--", path.relative(root, trackedPlaceholder)], { windowsHide: true });
  const stagedDoctor = runDoctor({ runtimeRoot, queueRoot });
  check(stagedDoctor.repository.status_lines.some((line) => line.includes("fleet/missions/complete_ready_for_gate/.gitkeep")), "Doctor reports the exact staged source change");
  equal(stagedDoctor.safe_to_start, false, "staged source change remains unsafe");
  execFileSync("git.exe", ["-C", root, "restore", "--staged", "--", path.relative(root, trackedPlaceholder)], { windowsHide: true });
  writeFileSync(trackedPlaceholder, trackedOriginal);

  const beforeStop = new Map(descriptors.map((descriptor) => [descriptor.path, sha256(readFileSync(descriptor.path))]));
  const stop = spawnSync(powershell, ["-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", stopScript], { cwd: root, encoding: "utf8", windowsHide: true, timeout: 30000 });
  check([0, 2, 3].includes(stop.status) || (stop.status === 1 && String(stop.stderr).includes("ACTIVE_HQ_DISPATCH_OWNER_NOT_CONFIRMED:ABSENT")), `Stop returns the exact fail-closed no-owner disposition: exit=${stop.status} stderr=${String(stop.stderr).trim()}`);
  for (const [file, hash] of beforeStop) equal(sha256(readFileSync(file)), hash, "Stop preserves every canonical generated record byte-for-byte");
  equal(doctorRuntimePolicy(runDoctor({ runtimeRoot, queueRoot, allowDirtyForTest: true })).status, "GREEN", "Doctor returns to canonical runtime safety after adversarial and source sentinels are removed");
} finally {
  rmSync(sentinel, { force: true });
  try { execFileSync("git.exe", ["-C", root, "restore", "--staged", "--", path.relative(root, trackedPlaceholder)], { windowsHide: true, stdio: "ignore" }); } catch {}
  writeFileSync(trackedPlaceholder, trackedOriginal);
  for (const link of createdLinks) rmSync(link, { force: true, recursive: false });
  for (const file of [...new Set(created)]) rmSync(file, { force: true });
  rmSync(fixtureRoot, { recursive: true, force: true });
}

console.log(`TSF_RUNTIME_QUEUE_CLEANLINESS_PASS assertions=${assertions}`);
