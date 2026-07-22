import assert from "node:assert/strict";
import { createInterface } from "node:readline";
import { spawn, spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import {
  POWERSHELL_EXE,
  ProcessOwnership,
  inspectProcess,
  inspectProcessWithParent,
} from "../tools/hq-dispatch/v1/reliability.mjs";

let assertions = 0;
const check = (value, message) => { assertions += 1; assert.ok(value, message); };
const equal = (actual, expected, message) => { assertions += 1; assert.equal(actual, expected, message); };
const waitForClose = (child) => new Promise((resolve, reject) => {
  child.once("close", (code, signal) => resolve({ code, signal }));
  child.once("error", reject);
});

const root = mkdtempSync(path.join(os.tmpdir(), "tsf-owned-registry-"));
const owner = new ProcessOwnership({
  repositoryRoot: process.cwd(),
  ownerPath: path.join(root, "owner.json"),
  tokenPath: path.join(root, "stop-token"),
  mode: "M3_PROCESS_OWNERSHIP_TEST",
});
let executor = null;
const descendantIds = [];
try {
  owner.claim();
  executor = spawn(POWERSHELL_EXE, ["-NoLogo", "-NoProfile", "-NonInteractive", "-Command", [
    `$child1 = Start-Process -FilePath '${POWERSHELL_EXE}' -ArgumentList @('-NoLogo','-NoProfile','-NonInteractive','-Command','Start-Sleep -Seconds 60') -PassThru -WindowStyle Hidden`,
    `$child2 = Start-Process -FilePath '${POWERSHELL_EXE}' -ArgumentList @('-NoLogo','-NoProfile','-NonInteractive','-Command','Start-Sleep -Seconds 60') -PassThru -WindowStyle Hidden`,
    `$child3 = Start-Process -FilePath '${POWERSHELL_EXE}' -ArgumentList @('-NoLogo','-NoProfile','-NonInteractive','-Command','Start-Sleep -Seconds 60') -PassThru -WindowStyle Hidden`,
    "[pscustomobject]@{child_process_ids=@($child1.Id,$child2.Id,$child3.Id)} | ConvertTo-Json -Compress",
    "Start-Sleep -Seconds 60",
  ].join("; ")], { windowsHide: true, stdio: ["ignore", "pipe", "pipe"] });
  owner.childStarted(executor);
  const childRow = await new Promise((resolve, reject) => {
    const lines = createInterface({ input: executor.stdout, crlfDelay: Infinity });
    const timer = setTimeout(() => reject(new Error("OWNED_REGISTRY_DESCENDANT_READY_TIMEOUT")), 10_000);
    lines.once("line", (line) => { clearTimeout(timer); resolve(JSON.parse(line)); });
    executor.once("error", (error) => { clearTimeout(timer); reject(error); });
  });
  descendantIds.push(...childRow.child_process_ids.map(Number));
  const rootIdentity = inspectProcessWithParent(executor.pid);
  const descendants = descendantIds.map((processId) => inspectProcessWithParent(processId));
  check(rootIdentity && descendants.every(Boolean), "controlled root and descendants expose exact PID/start-time identities");
  if (descendants.some((identity) => Number(identity.parent_process_id) !== Number(executor.pid))) {
    throw new Error(`OWNED_REGISTRY_FIXTURE_PARENT_MISMATCH:${JSON.stringify({ executor: executor.pid, descendants })}`);
  }
  const causalRegistrationAt = new Date().toISOString();
  const registrationBase = {
    rootProcessId: executor.pid,
    serverInstanceId: owner.serverInstanceId,
    capabilityIdentitySha256: "c".repeat(64),
    ownershipEvidenceSha256: "d".repeat(64),
    launchIdentitySha256: "e".repeat(64),
  };
  const bindParent = (identity) => ({
    ...identity,
    parent_process_start_time: rootIdentity.process_start_time,
    parent_executable: rootIdentity.executable,
  });
  owner.childrenStartedFromEvidence({
    ...registrationBase,
    processes: [bindParent(descendants[0])],
    registrationCreatedAt: causalRegistrationAt,
  });
  const cutoff = owner.beginOwnedProcessShutdown("SYNTHETIC_ROOT_INDEPENDENT_STOP");
  equal(cutoff.generation, 2, "shutdown captures root plus first descendant generation");
  owner.childrenStartedFromEvidence({
    ...registrationBase,
    processes: [bindParent(descendants[1])],
    registrationCreatedAt: causalRegistrationAt,
  });
  equal(owner.ownedProcessRegistrySnapshot().generation, 3, "causally valid late registration advances the cleanup generation");
  assert.throws(() => owner.childrenStartedFromEvidence({
    ...registrationBase,
    processes: [bindParent(descendants[2])],
    registrationCreatedAt: new Date(Date.now() + 1000).toISOString(),
  }), /OWNED_PROCESS_LATE_REGISTRATION_UNVERIFIED/);
  assertions += 1;
  check(inspectProcess(descendantIds[2]), "unverifiable late process remains outside TSF cleanup authority");

  const executorClose = waitForClose(executor);
  executor.kill();
  await executorClose;
  owner.childExited(executor.pid);
  const afterRootClose = owner.ownedProcessRegistrySnapshot();
  equal(afterRootClose.entries.length, 3, "root close clears no immutable registry entry");
  equal(afterRootClose.entries.filter((entry) => entry.process_id !== executor.pid && !entry.terminal_cleanup_disposition).length, 2, "registered descendants remain pending after root close");
  check(owner.owner.owned_children.every((entry) => entry.process_id !== executor.pid), "live root pointer evidence may clear independently");
  check(owner.owner.owned_children.some((entry) => entry.process_id === descendantIds[0]), "root close retains descendant ownership evidence");

  const cleanup = await owner.cleanupRegisteredOwnedProcesses({ liveRootChild: null, reason: "SYNTHETIC_ROOT_INDEPENDENT_STOP", cooperativeWaitMs: 25 });
  equal(cleanup.status, "CLEANUP_CONFIRMED", "root-independent cleanup confirms every registered process");
  equal(cleanup.registry_generation, 3, "finalization uses the stable advanced registry generation");
  equal(cleanup.terminal_dispositions.length, 3, "each registered identity receives exactly one terminal disposition");
  equal(new Set(cleanup.terminal_dispositions.map((entry) => `${entry.process_id}|${entry.process_start_time}`)).size, 3, "terminal dispositions are unique by exact identity");
  check(cleanup.terminal_dispositions.every((entry) => ["COOPERATIVE_EXIT_CONFIRMED", "FORCED_TERMINATION_CONFIRMED", "ALREADY_GONE_WITH_IDENTITY_CONFIRMED"].includes(entry.terminal_disposition)), "only closed terminal dispositions permit finalization");
  check(descendantIds.slice(0, 2).every((processId) => !inspectProcess(processId)), "registered descendants are cleaned without a root handle");
  check(inspectProcess(descendantIds[2]), "unregistered controlled process is never targeted by registry cleanup");
  owner.childrenExitedFromEvidence({ ...registrationBase, processes: descendants.slice(0, 2).map(bindParent) });

  const events = readFileSync(cleanup.registry_path, "utf8").split(/\r?\n/).filter(Boolean).map((line) => JSON.parse(line));
  equal(events.every((event, index) => event.sequence === index + 1), true, "registry event sequence is append-only and monotonic");
  equal(events.every((event, index) => index === 0 ? event.previous_evidence_sha256 === null : event.previous_evidence_sha256 === events[index - 1].evidence_sha256), true, "registry evidence hash chain is closed");
  check(events.some((event) => event.event_type === "LATE_PROCESS_REGISTERED"), "valid late registration is durably classified");
  check(events.some((event) => event.event_type === "LATE_REGISTRATION_REJECTED"), "unverifiable late registration fails closed durably");
  equal(events.at(-1).event_type, "REGISTRY_GENERATION_STABLE", "stable generation is the terminal registry event");
} finally {
  for (const processId of descendantIds) {
    const observed = inspectProcess(processId);
    if (observed) spawnSync("C:\\Windows\\System32\\taskkill.exe", ["/PID", String(processId), "/F"], { windowsHide: true });
  }
  if (executor && inspectProcess(executor.pid)) executor.kill();
  owner.release();
  rmSync(root, { recursive: true, force: true });
}

process.stdout.write(`${JSON.stringify({ schema_version: "tsf_owned_process_registry_adversarial_v1", status: "PASS", assertions })}\n`);
