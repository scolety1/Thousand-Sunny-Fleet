import { existsSync, mkdirSync } from "node:fs";
import path from "node:path";
import { createHqDispatchServer, listenHqDispatchServer } from "./server.mjs";
import { createDemoFixtureAdapters, resetDemoFixtureRoot } from "./demo-fixtures.mjs";
import {
  HQ_HOST,
  HQ_PORT,
  LOCAL_LIFECYCLE_ROOT,
  OWNER_PATH,
  ProcessOwnership,
  REPOSITORY_ROOT,
  STOP_TOKEN_PATH,
  reconcileCanonicalState,
  runDoctor,
  writeInterruptionEvidence,
} from "./reliability.mjs";

const FIXTURE_ROOT = path.join(REPOSITORY_ROOT, ".codex-local", "fixtures", "hq-dispatch-demo-v1");
const RUNTIME_ROOT = path.join(FIXTURE_ROOT, "runtime");
const QUEUE_ROOT = path.join(FIXTURE_ROOT, "queue");
const RECOVERY_ROOT = path.join(FIXTURE_ROOT, "lifecycle");

async function main() {
  const args = process.argv.slice(2);
  if (args.some((arg) => arg !== "--reset") || args.filter((arg) => arg === "--reset").length > 1) throw new Error("HQ_DEMO_ARGUMENT_REJECTED");
  if (args.includes("--reset") && existsSync(FIXTURE_ROOT)) {
    resetDemoFixtureRoot({ fixtureRoot: FIXTURE_ROOT, repositoryRoot: REPOSITORY_ROOT });
  }
  for (const root of [RUNTIME_ROOT, QUEUE_ROOT, RECOVERY_ROOT]) mkdirSync(root, { recursive: true });
  const doctor = runDoctor({ runtimeRoot: RUNTIME_ROOT, queueRoot: QUEUE_ROOT, ownerPath: OWNER_PATH, port: HQ_PORT, allowDirtyForTest: true, demoMode: true });
  if (!doctor.safe_to_start) throw new Error(`HQ_DEMO_START_BLOCKED:${doctor.overall_status}`);
  const owner = new ProcessOwnership({ ownerPath: OWNER_PATH, tokenPath: STOP_TOKEN_PATH, host: HQ_HOST, port: HQ_PORT, mode: "DEMO_FIXTURE_ONLY" });
  owner.claim();
  const adapters = createDemoFixtureAdapters({ fixtureRoot: FIXTURE_ROOT, repositoryRoot: REPOSITORY_ROOT, queueRoot: QUEUE_ROOT, runtimeRoot: RUNTIME_ROOT });
  let server;
  let closing;
  try {
    const lifecycle = {
      mode: "DEMO_FIXTURE_ONLY",
      owner,
      localRoot: RECOVERY_ROOT,
      sessionGeneration: owner.sessionGeneration,
      serverInstanceId: owner.serverInstanceId,
      doctor: () => runDoctor({ runtimeRoot: RUNTIME_ROOT, queueRoot: QUEUE_ROOT, ownerPath: OWNER_PATH, port: HQ_PORT, allowDirtyForTest: true, demoMode: true }),
      reconcile: () => reconcileCanonicalState({ runtimeRoot: RUNTIME_ROOT, queueRoot: QUEUE_ROOT }),
      stopView: () => ({ schema_version: "tsf_hq_dispatch_stop_view_v1", server_instance: owner.serverInstanceId, mode: "DEMO_FIXTURE_ONLY", active_mission: owner.owner?.active_mission ?? null, owned_child: owner.owner?.owned_children ?? [], behavior: "Exact owned demo fixture process only.", remaining_canonical_work: reconcileCanonicalState({ runtimeRoot: RUNTIME_ROOT, queueRoot: QUEUE_ROOT }).items }),
      authenticateStop: (token, body) => owner.authenticateStop(token, body),
      recordInterruption: (record) => {
        const reconciliation = reconcileCanonicalState({ runtimeRoot: RUNTIME_ROOT, queueRoot: QUEUE_ROOT });
        const item = reconciliation.items.find((candidate) => candidate.mission_id === record.missionId && candidate.mission_revision === record.revision);
        return item ? writeInterruptionEvidence({ item, reason: "DEMO_SERVER_SHUTDOWN_DURING_FIXTURE", serverInstanceId: owner.serverInstanceId, operatorInitiated: true }) : null;
      },
      requestStop: null,
    };
    server = createHqDispatchServer({ lifecycle, executionAdapter: adapters.executionAdapter, responseAdapter: adapters.responseAdapter, testOnlyQueueRoot: QUEUE_ROOT });
    const close = (reason) => {
      if (!closing) closing = (async () => { await server.hqDispatchShutdown(reason); await new Promise((resolve) => server.listening ? server.close(resolve) : resolve()); owner.release(); })();
      return closing;
    };
    lifecycle.requestStop = close;
    await listenHqDispatchServer(server, HQ_PORT);
    owner.activate();
    process.stdout.write(`TSF HQ Dispatch Demo V1 listening at http://${HQ_HOST}:${HQ_PORT}\nFIXTURE BEHAVIOR — NOT REAL APP-SERVER BEHAVIOR\nDemo fixture root: ${FIXTURE_ROOT}\nCanonical production-style mission roots are not used. Type a request containing TIM REQUIRED to demonstrate the Milestone 2B response path.\n`);
    process.once("SIGINT", () => { void close("SIGINT"); });
    process.once("SIGTERM", () => { void close("SIGTERM"); });
  } catch (error) {
    if (server?.listening) await new Promise((resolve) => server.close(resolve));
    owner.release();
    throw error;
  }
}

main().catch((error) => { process.stderr.write(`HQ Dispatch demo failed closed: ${error instanceof Error ? error.message : "UNKNOWN"}\n`); process.exitCode = 1; });
