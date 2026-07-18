import assert from "node:assert/strict";
import { spawn, spawnSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, rmSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import {
  POWERSHELL_EXE,
  ProcessOwnership,
  inspectProcess,
} from "../tools/hq-dispatch/v1/reliability.mjs";
import {
  ProcessActionLedger,
  readProcessActionLedger,
  validateRegistryLedgerSynchronization,
} from "./support/tsf-process-action-ledger.mjs";

let assertions = 0;
const check = (value, message) => { assertions += 1; assert.ok(value, message); };
const equal = (actual, expected, message) => { assertions += 1; assert.equal(actual, expected, message); };
const ownedSleep = () => spawn(POWERSHELL_EXE, ["-NoLogo", "-NoProfile", "-NonInteractive", "-Command", "Start-Sleep -Seconds 60"], { windowsHide: true, stdio: "ignore" });
const exactKill = (child) => {
  if (child?.pid && inspectProcess(child.pid)) spawnSync("C:\\Windows\\System32\\taskkill.exe", ["/PID", String(child.pid), "/F"], { windowsHide: true });
};
const createFixture = (label) => {
  const root = mkdtempSync(path.join(os.tmpdir(), `tsf-owned-registration-${label}-`));
  const owner = new ProcessOwnership({
    repositoryRoot: process.cwd(),
    ownerPath: path.join(root, "owner.json"),
    tokenPath: path.join(root, "stop-token"),
    mode: "M3_PROCESS_OWNERSHIP_TEST",
  });
  const ledgerPath = path.join(root, "PROCESS_ACTION_LEDGER.jsonl");
  const ledger = new ProcessActionLedger({ filePath: ledgerPath, writerIdentity: `registration-test-${label}` });
  owner.setProcessActionRecorder((action) => ledger.record({
    ...action,
    proof_identity: `registration-test-${label}`,
    candidate_worktree: process.cwd(),
    candidate_commit: "a".repeat(40),
  }), { ledgerPath });
  owner.claim();
  return { root, owner, ledger, ledgerPath };
};

{
  const fixture = createFixture("normal");
  const child = ownedSleep();
  try {
    fixture.owner.childStarted(child);
    const snapshot = fixture.owner.ownedProcessRegistrySnapshot();
    equal(snapshot.entries.length, 1, "normal registration creates one immutable registry entry");
    equal(snapshot.entries[0].registration_status, "COMMITTED", "normal registration becomes committed only after both durable writes");
    const events = readProcessActionLedger(fixture.ledgerPath);
    const reconciliation = validateRegistryLedgerSynchronization(snapshot.entries, events);
    equal(reconciliation.ownership_ledger_events, 1, "normal registration has exactly one matching ownership event");
    equal(events[0].process_registration_id, snapshot.entries[0].process_registration_id, "registry and ledger share one registration id");
    equal(events[0].registration_sequence, snapshot.entries[0].registration_sequence, "registry and ledger share one registration sequence");
    const cleanup = await fixture.owner.cleanupRegisteredOwnedProcesses({ reason: "NORMAL_REGISTRATION_TEST", cooperativeWaitMs: 0 });
    equal(cleanup.status, "CLEANUP_CONFIRMED", "terminal cleanup is allowed after committed registration");
    validateRegistryLedgerSynchronization(fixture.owner.ownedProcessRegistrySnapshot().entries, readProcessActionLedger(fixture.ledgerPath));
    assertions += 1;
  } finally {
    exactKill(child);
    fixture.owner.release();
    rmSync(fixture.root, { recursive: true, force: true });
  }
}

{
  const fixture = createFixture("early-exit");
  const child = ownedSleep();
  let injected = false;
  fixture.owner.setProcessActionRecorder((action) => {
    const event = fixture.ledger.record({
      ...action,
      proof_identity: "registration-test-early-exit",
      candidate_worktree: process.cwd(),
      candidate_commit: "a".repeat(40),
    });
    if (!injected && action.action_type === "REGISTER_PROOF_OWNERSHIP") {
      injected = true;
      exactKill(child);
      fixture.owner.childExited(child.pid);
    }
    return event;
  }, { ledgerPath: fixture.ledgerPath });
  try {
    fixture.owner.childStarted(child);
    const snapshot = fixture.owner.ownedProcessRegistrySnapshot();
    equal(snapshot.entries[0].registration_status, "COMMITTED", "early exit does not bypass registration commitment");
    equal(snapshot.entries[0].terminal_cleanup_disposition, "ALREADY_GONE_WITH_IDENTITY_CONFIRMED", "buffered early exit receives one truthful terminal disposition after commitment");
    const events = readProcessActionLedger(fixture.ledgerPath);
    validateRegistryLedgerSynchronization(snapshot.entries, events);
    assertions += 1;
    const registrationIndex = events.findIndex((event) => event.action_type === "REGISTER_PROOF_OWNERSHIP");
    const observationIndex = events.findIndex((event) => event.action_type === "OBSERVE_PROCESS");
    const terminalIndex = events.findIndex((event) => event.action_type === "CONFIRM_PROCESS_EXIT");
    check(registrationIndex >= 0 && registrationIndex < observationIndex && observationIndex < terminalIndex, "durable causal order is registration, exit observation, terminal disposition");
    check(Date.parse(events[observationIndex].observed_exit_or_close_at) <= Date.parse(events[terminalIndex].utc_timestamp), "truthful early observation timestamp is preserved");
    equal(events.filter((event) => event.action_type === "CONFIRM_PROCESS_EXIT").length, 1, "early exit produces exactly one terminal event");
  } finally {
    exactKill(child);
    fixture.owner.release();
    rmSync(fixture.root, { recursive: true, force: true });
  }
}

{
  const fixture = createFixture("partial-write");
  const child = ownedSleep();
  fixture.owner.setProcessActionRecorder(() => { throw new Error("INJECTED_LEDGER_WRITE_FAILURE"); }, { ledgerPath: fixture.ledgerPath });
  try {
    assert.throws(() => fixture.owner.childStarted(child), /OWNED_PROCESS_REGISTRATION_COMMIT_FAILED:INJECTED_LEDGER_WRITE_FAILURE/);
    assertions += 1;
    const snapshot = fixture.owner.ownedProcessRegistrySnapshot();
    equal(snapshot.entries[0].registration_status, "INCOMPLETE_LEDGER_WRITE_FAILED", "registry-only partial write remains explicitly incomplete");
    assert.throws(() => fixture.owner.reconcileOwnedProcessRegistryAndLedger(), /OWNED_PROCESS_REGISTRY_LEDGER_REGISTRATION_INCOMPLETE/);
    assertions += 1;
    await assert.rejects(() => fixture.owner.cleanupRegisteredOwnedProcesses({ reason: "PARTIAL_WRITE_TEST", cooperativeWaitMs: 0 }), /OWNED_PROCESS_REGISTRY_LEDGER_REGISTRATION_INCOMPLETE/);
    assertions += 1;
    check(inspectProcess(child.pid), "incomplete registration is not used as an owned cleanup target");
    equal(snapshot.entries[0].terminal_cleanup_disposition, null, "partial registration cannot receive an owned terminal disposition");
    check(!existsSync(fixture.ledgerPath), "failed causal-ledger write does not fabricate a durable ownership event");
  } finally {
    exactKill(child);
    fixture.owner.release();
    rmSync(fixture.root, { recursive: true, force: true });
  }
}

{
  const orphan = {
    action_type: "REGISTER_PROOF_OWNERSHIP",
    process_registration_id: "owned-process-orphan",
    registration_sequence: 1,
    target_process_id: 100,
    target_process_start_time: new Date().toISOString(),
  };
  assert.throws(() => validateRegistryLedgerSynchronization([], [orphan]), /OWNED_PROCESS_LEDGER_WITHOUT_REGISTRY_REGISTRATION/);
  assertions += 1;
}

{
  const fixture = createFixture("adversarial-reconciliation");
  const child = ownedSleep();
  try {
    fixture.owner.childStarted(child);
    const entries = fixture.owner.ownedProcessRegistrySnapshot().entries;
    const events = readProcessActionLedger(fixture.ledgerPath);
    assert.throws(() => validateRegistryLedgerSynchronization(entries, [...events, { ...events[0], evidence_sha256: "b".repeat(64) }]), /OWNED_PROCESS_DUPLICATE_LEDGER_REGISTRATION/);
    assertions += 1;
    assert.throws(() => validateRegistryLedgerSynchronization(entries, [{ ...events[0], target_process_start_time: new Date(Date.parse(events[0].target_process_start_time) + 1000).toISOString() }]), /OWNED_PROCESS_REGISTRY_LEDGER_START_TIME_MISMATCH/);
    assertions += 1;
    const prematureTerminal = { ...events[0], action_type: "CONFIRM_PROCESS_EXIT", terminal_disposition: "ALREADY_GONE_WITH_IDENTITY_CONFIRMED" };
    assert.throws(() => validateRegistryLedgerSynchronization(entries, [prematureTerminal, events[0]]), /OWNED_PROCESS_EXIT_OBSERVATION_MISSING/);
    assertions += 1;
  } finally {
    exactKill(child);
    fixture.owner.release();
    rmSync(fixture.root, { recursive: true, force: true });
  }
}

process.stdout.write(`${JSON.stringify({ schema_version: "tsf_owned_process_registration_synchronization_adversarial_v1", status: "PASS", assertions })}\n`);
