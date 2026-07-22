import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { readFileSync, rmSync, writeFileSync } from "node:fs";
import path from "node:path";
import {
  REPOSITORY_ROOT,
} from "../tools/hq-dispatch/v1/reliability.mjs";
import { FIXTURE_RELATIVE_ROOT } from "./support/tsf-hq-dispatch-m3-real-interruption-barrier.mjs";
import {
  allocateInitialDoctorIsolation,
  runInitialDoctorPair,
  validateInitialDoctorIsolation,
} from "./support/tsf-hq-dispatch-initial-doctor-isolation.mjs";

let assertions = 0;
function check(value, message) { assertions += 1; assert.ok(value, message); }
function equal(actual, expected, message) { assertions += 1; assert.deepEqual(actual, expected, message); }
function rejects(action, expression, message) { assertions += 1; assert.throws(action, expression, message); }

function allocate(label) {
  return allocateInitialDoctorIsolation({
    repositoryRoot: REPOSITORY_ROOT,
    fixtureRelativeRoot: FIXTURE_RELATIVE_ROOT,
    testRunIdentity: `run-${label}-${process.pid}-${randomUUID().slice(0, 8)}`,
  });
}

const fresh = allocate("fresh");
const first = runInitialDoctorPair(fresh);
equal(first.report.safe_to_start, true, "fresh isolated roots are safely startable on the first invocation");
equal(first.diagnostic.classification_agreement, true, "human and JSON Doctor classifications agree");
equal(first.diagnostic.json.exit_code, 0, "fresh JSON Doctor exits zero without retry");
equal(first.diagnostic.human.exit_code, 0, "fresh human Doctor exits zero without retry");
equal(first.diagnostic.blocking_findings.length, 0, "fresh first-attempt diagnostic contains no blocking check");
equal(first.diagnostic.runtime_queue_inventory.unknown_or_invalid_count, 0, "fresh queue has no inherited state");

const queueLeak = allocate("queue-leak");
writeFileSync(path.join(queueLeak.queue_root, "precreated-queue-state.json"), "{}\n", { encoding: "utf8", flag: "wx" });
const queueBlocked = runInitialDoctorPair(queueLeak, { requireSafe: false });
equal(queueBlocked.report.safe_to_start, false, "precreated queue state is unsafe on the first invocation");
check(queueBlocked.diagnostic.blocking_findings.some((item) => item.id === "runtime_queue_evidence_policy"), "queue leakage diagnostic identifies the exact blocking policy check");
check(queueBlocked.diagnostic.checks.find((item) => item.id === "runtime_queue_evidence_policy")?.evidence_paths.length > 0, "queue leakage diagnostic includes check evidence paths");

const protectedUnknown = allocate("protected-unknown");
writeFileSync(path.join(protectedUnknown.queue_root, "UNKNOWN_PROTECTED_FILE.bin"), "not a canonical queue document\n", { encoding: "utf8", flag: "wx" });
const protectedBlocked = runInitialDoctorPair(protectedUnknown, { requireSafe: false });
equal(protectedBlocked.report.safe_to_start, false, "precreated protected unknown runtime file is unsafe");
check(protectedBlocked.diagnostic.blocking_findings.some((item) => item.id === "runtime_queue_evidence_policy"), "protected unknown diagnostic identifies the protected queue policy");

const shared = allocate("shared-root-source");
const target = allocate("shared-root-target");
rejects(() => validateInitialDoctorIsolation({ ...target, owner_root: shared.owner_root, owner_path: shared.owner_path, token_path: shared.token_path }), /ISOLATION_OWNER_ROOT_NOT_UNIQUE/, "shared owner root is rejected before Doctor");
rejects(() => validateInitialDoctorIsolation({ ...target, runtime_root: shared.runtime_root }), /ISOLATION_RUNTIME_ROOT_NOT_UNIQUE/, "shared runtime root is rejected before Doctor");

const environmentCase = allocate("environment");
const savedRuntime = process.env.TSF_HQ_RUNTIME_ROOT;
const savedQueue = process.env.TSF_HQ_QUEUE_ROOT;
const savedOwner = process.env.TSF_HQ_OWNER_ROOT;
process.env.TSF_HQ_RUNTIME_ROOT = shared.runtime_root;
process.env.TSF_HQ_QUEUE_ROOT = shared.queue_root;
process.env.TSF_HQ_OWNER_ROOT = shared.owner_root;
try {
  const environmentResult = runInitialDoctorPair(environmentCase, { environmentBefore: {
    TSF_HQ_RUNTIME_ROOT: process.env.TSF_HQ_RUNTIME_ROOT,
    TSF_HQ_QUEUE_ROOT: process.env.TSF_HQ_QUEUE_ROOT,
    TSF_HQ_OWNER_ROOT: process.env.TSF_HQ_OWNER_ROOT,
  } });
  equal(environmentResult.report.canonical_runtime_root, path.resolve(environmentCase.runtime_root), "stale environment cannot redirect the explicit runtime root");
  equal(environmentResult.report.canonical_queue_root, path.resolve(environmentCase.queue_root), "stale environment cannot redirect the explicit queue root");
  equal(environmentResult.report.local_lifecycle_root, path.resolve(environmentCase.owner_root), "stale environment cannot redirect the explicit owner root");
} finally {
  if (savedRuntime === undefined) delete process.env.TSF_HQ_RUNTIME_ROOT; else process.env.TSF_HQ_RUNTIME_ROOT = savedRuntime;
  if (savedQueue === undefined) delete process.env.TSF_HQ_QUEUE_ROOT; else process.env.TSF_HQ_QUEUE_ROOT = savedQueue;
  if (savedOwner === undefined) delete process.env.TSF_HQ_OWNER_ROOT; else process.env.TSF_HQ_OWNER_ROOT = savedOwner;
}

const failedDiagnosticBytes = readFileSync(queueBlocked.diagnostic.diagnostic_path);
rmSync(path.join(queueLeak.queue_root, "precreated-queue-state.json"), { force: true });
const laterClean = allocate("later-clean");
const laterGreen = runInitialDoctorPair(laterClean);
equal(laterGreen.report.safe_to_start, true, "independent later clean Doctor can be GREEN");
equal(readFileSync(queueBlocked.diagnostic.diagnostic_path).equals(failedDiagnosticBytes), true, "later GREEN cannot replace the failed first-attempt diagnostic");
equal(queueBlocked.report.safe_to_start, false, "failed first-attempt classification remains failed");

process.stdout.write(`${JSON.stringify({
  schema_version: "tsf_hq_dispatch_initial_doctor_isolation_adversarial_v1",
  status: "PASS",
  assertions,
  fresh_first_attempt_identity: fresh.test_run_identity,
  queue_leak_identity: queueLeak.test_run_identity,
  protected_unknown_identity: protectedUnknown.test_run_identity,
  later_green_identity: laterClean.test_run_identity,
  queue_blocking_check_ids: queueBlocked.diagnostic.blocking_findings.map((item) => item.id),
  protected_blocking_check_ids: protectedBlocked.diagnostic.blocking_findings.map((item) => item.id),
  retry_used_for_fresh_case: false,
}, null, 2)}\n`);
