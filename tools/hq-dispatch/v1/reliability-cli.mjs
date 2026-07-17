import { existsSync } from "node:fs";
import {
  OWNER_PATH,
  STOP_TOKEN_PATH,
  inspectListeners,
  inspectProcess,
  recoverVerifiedStaleOwnership,
  runDoctor,
  stopRequestEvidence,
} from "./reliability.mjs";

function write(value, stream = process.stdout) {
  stream.write(`${JSON.stringify(value, null, 2)}\n`);
}

async function waitForExactStop(owner) {
  const deadline = Date.now() + 30000;
  while (Date.now() < deadline) {
    const processGone = !inspectProcess(owner.process_id);
    const childProcessesGone = (owner.owned_children ?? []).every((child) => !inspectProcess(child.process_id));
    const exactListenerGone = !inspectListeners(owner.port).some((listener) => Number(listener.process_id) === owner.process_id);
    const ownerRecordGone = !existsSync(OWNER_PATH);
    if (processGone && childProcessesGone && exactListenerGone && ownerRecordGone) {
      return { process_gone: true, owned_children_gone: true, exact_listener_gone: true, ownership_record_gone: true };
    }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  return {
    process_gone: !inspectProcess(owner.process_id),
    owned_children_gone: (owner.owned_children ?? []).every((child) => !inspectProcess(child.process_id)),
    exact_listener_gone: !inspectListeners(owner.port).some((listener) => Number(listener.process_id) === owner.process_id),
    ownership_record_gone: !existsSync(OWNER_PATH),
  };
}

async function stop() {
  const { owner, token, listeners } = stopRequestEvidence();
  const response = await fetch(`http://${owner.host}:${owner.port}/api/v1/admin/stop`, {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
      "X-TSF-HQ-Stop": token,
      Host: `${owner.host}:${owner.port}`,
    },
    body: JSON.stringify({ server_instance_id: owner.server_instance_id, evidence_hash: owner.evidence_hash, process_id: owner.process_id }),
  });
  let accepted;
  try { accepted = await response.json(); } catch { accepted = null; }
  if (response.status !== 202) throw new Error(`EXACT_OWNER_STOP_REJECTED:${response.status}:${accepted?.error?.code ?? "UNKNOWN"}`);
  const cleanup = await waitForExactStop(owner);
  const complete = Object.values(cleanup).every(Boolean);
  const remainingListeners = inspectListeners(owner.port);
  const result = {
    schema_version: "tsf_hq_dispatch_stop_result_v1",
    status: complete ? "GREEN" : "UNSAFE_TO_START",
    server_instance_id: owner.server_instance_id,
    targeted_process_id: owner.process_id,
    verified_process_start_time: owner.process_start_time,
    verified_executable: owner.executable,
    verified_repository: owner.repository,
    accepted,
    cleanup,
    remaining_listeners: remainingListeners,
    unrelated_processes_terminated: false,
    operator_session_invalidated: Boolean(accepted?.operator_session_invalidated),
    canonical_records_preserved: Boolean(accepted?.canonical_records_preserved),
    exact_next_action: complete ? "Run Test-TsfHqDispatchDoctorV1.ps1 before the next Start." : "Preserve ownership evidence and run Doctor; do not target any PID manually.",
    listeners_observed_before_stop: listeners,
  };
  write(result);
  if (!complete) process.exitCode = 4;
}

async function main() {
  const [command, ...extra] = process.argv.slice(2);
  if (extra.length || !["doctor", "doctor-start-gate", "stop", "recover-stale-owner"].includes(command)) {
    process.stderr.write("Usage: node reliability-cli.mjs <doctor|doctor-start-gate|stop|recover-stale-owner>\n");
    process.exitCode = 64;
    return;
  }
  if (command === "doctor" || command === "doctor-start-gate") {
    const report = runDoctor();
    write(report);
    if (command === "doctor-start-gate") {
      if (!report.safe_to_start) process.exitCode = 4;
      return;
    }
    process.exitCode = { GREEN: 0, GREEN_WITH_CAVEATS: 0, ACTION_REQUIRED: 2, TIM_REQUIRED: 3, UNSAFE_TO_START: 4 }[report.overall_status] ?? 4;
    return;
  }
  if (command === "recover-stale-owner") {
    write(recoverVerifiedStaleOwnership({ ownerPath: OWNER_PATH, tokenPath: STOP_TOKEN_PATH }));
    return;
  }
  await stop();
}

main().catch((error) => {
  write({ schema_version: "tsf_hq_dispatch_lifecycle_error_v1", status: "UNSAFE_TO_START", error: error instanceof Error ? error.message : "UNKNOWN", exact_next_action: "Run Test-TsfHqDispatchDoctorV1.ps1 and follow its evidence-bound next action. No arbitrary process is terminated." }, process.stderr);
  process.exitCode = 1;
});
