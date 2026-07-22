import assert from "node:assert/strict";
import { closeSync, fsyncSync, mkdirSync, openSync, writeSync } from "node:fs";
import { createServer } from "node:http";
import path from "node:path";
import { once } from "node:events";
import { ProofTraceRecorder } from "./support/tsf-proof-fetch-trace.mjs";

const level = Number(process.argv.find((value) => value.startsWith("--level="))?.split("=")[1] ?? 0);
const variant = process.argv.find((value) => value.startsWith("--variant="))?.split("=")[1] ?? "safe";
const evidenceRoot = path.resolve(process.env.TSF_NATIVE_TEST_EVIDENCE_ROOT ?? "");
assert.ok(Number.isInteger(level) && level >= 1 && level <= 6, "NATIVE_LADDER_LEVEL_REQUIRED_1_TO_6");
assert.ok(process.env.TSF_NATIVE_TEST_EVIDENCE_ROOT, "TSF_NATIVE_TEST_EVIDENCE_ROOT_REQUIRED");
mkdirSync(evidenceRoot, { recursive: true });
const stagePath = path.join(evidenceRoot, "NATIVE_TEST_STAGE_TRACE.json");
const resultPath = path.join(evidenceRoot, "NATIVE_TEST_RESULT.json");
const events = [];
const writeDurable = (filePath, value) => {
  const bytes = Buffer.from(`${JSON.stringify(value, null, 2)}\n`, "utf8");
  const handle = openSync(filePath, "w");
  try { writeSync(handle, bytes); fsyncSync(handle); } finally { closeSync(handle); }
};
const stage = (stageId, details = {}) => {
  events.push({ sequence: events.length + 1, stage_id: stageId, utc: new Date().toISOString(), level, variant, ...details });
  writeDurable(stagePath, { schema_version: "tsf_native_reproduction_ladder_trace_v1", process_id: process.pid, parent_process_id: process.ppid, events });
};

let server = null;
let port = 0;
let instance = `ladder-${level}-${variant}`;
let slowSettled = Promise.resolve();
const owner = () => ({ disposition: server?.listening ? "ACTIVE_OWNER_CONFIRMED" : "ABSENT", owner: server?.listening ? { server_instance_id: instance, operator_session_generation: "ladder-generation", process_id: process.pid, process_start_time: "TEST_ONLY", lifecycle_state: "ACTIVE", active_mission: null, owned_children: [] } : null });
const listeners = (expectedPort) => server?.listening && Number(expectedPort) === port ? [{ host: "127.0.0.1", port, process_id: process.pid, evidence_source: "NATIVE_LADDER" }] : [];
const closeExactServer = async (exactServer, label) => {
  if (!exactServer?.listening) { stage(`${label}_ALREADY_CLOSED`); return; }
  const closed = once(exactServer, "close");
  stage(`${label}_CLOSE_REQUESTED`, { port });
  exactServer.close();
  await closed;
  stage(`${label}_CLOSE_CONFIRMED`, { port });
};
const startServer = async ({ abortAware, handlerCloses }) => {
  const exactServer = createServer((req, res) => {
    if (req.url === "/ok") {
      const body = Buffer.from(JSON.stringify({ ok: true, server_instance_id: instance }));
      res.writeHead(200, { "Content-Type": "application/json", "Content-Length": body.length });
      res.end(body);
      return;
    }
    if (req.url === "/slow") {
      let settle;
      slowSettled = new Promise((resolve) => { settle = resolve; });
      const timer = setTimeout(() => {
        if (!res.destroyed) {
          const body = Buffer.from(JSON.stringify({ late: true }));
          res.writeHead(200, { "Content-Type": "application/json", "Content-Length": body.length });
          res.end(body);
        }
        stage("SLOW_TIMER_SETTLED", { response_destroyed: res.destroyed });
        settle();
      }, 200);
      if (abortAware) res.once("close", () => { clearTimeout(timer); stage("SLOW_ABORT_CLOSE_SETTLED"); settle(); });
      return;
    }
    if (req.url === "/stop") {
      const body = Buffer.from(JSON.stringify({ accepted: true, server_instance_id: instance }));
      res.once("finish", () => stage("STOP_RESPONSE_FINISHED"));
      res.writeHead(202, { "Content-Type": "application/json", "Content-Length": body.length });
      res.end(body);
      if (handlerCloses) setImmediate(() => { stage("HANDLER_DEFERRED_CLOSE_INVOKED"); server.close(); });
      return;
    }
    res.writeHead(404); res.end();
  });
  server = exactServer;
  await new Promise((resolve, reject) => { exactServer.once("error", reject); exactServer.listen(0, "127.0.0.1", resolve); });
  port = exactServer.address().port;
  stage("SERVER_LISTENING", { port, abort_aware: abortAware, handler_closes: handlerCloses });
  return exactServer;
};

let failure = null;
try {
  stage("LADDER_ENTERED");
  if (level === 1) {
    assert.equal(typeof ProofTraceRecorder, "function");
    stage("IMPORT_AND_RUNTIME_IDENTITY_COMPLETE", { node: process.version, versions: process.versions });
  }
  if (level === 2) {
    const recorder = new ProofTraceRecorder({ evidenceRoot: path.join(evidenceRoot, "recorder"), port: 1 });
    const controlled = recorder.startStage("CONTROLLED_ONLY");
    recorder.failStage(controlled, "EXPECTED_CONTROLLED_FAILURE", {}, "CONTROLLED_FAILURE");
    recorder.writeFinal({ status: "PASS", exitCode: 0, result: { durable_only: true } });
    stage("DURABLE_RECORDER_ONLY_COMPLETE");
  }
  if (level >= 3) {
    const handlerCloses = variant === "current-handler-close";
    const abortAware = variant !== "current-handler-close";
    const exactServer = await startServer({ abortAware, handlerCloses });
    const recorder = new ProofTraceRecorder({ evidenceRoot: path.join(evidenceRoot, "proof"), port, inspectOwner: owner, inspectListeners: listeners });
    if (level === 3) {
      const response = await recorder.httpJson({ stageId: "ONE_OK", caller: "native-ladder", pathname: "/ok", expectedServerInstance: instance, expectedSessionGeneration: "ladder-generation" });
      assert.equal(response.status, 200);
      await closeExactServer(exactServer, "HARNESS");
    }
    if (level === 4) {
      const closed = once(exactServer, "close");
      const response = await recorder.httpJson({ stageId: "STOP_WITHOUT_ABORT", caller: "native-ladder", method: "POST", pathname: "/stop", expectedServerInstance: instance, expectedSessionGeneration: "ladder-generation" });
      assert.equal(response.status, 202);
      if (handlerCloses) { await closed; stage("HANDLER_CLOSE_CONFIRMED"); } else { await closeExactServer(exactServer, "HARNESS"); }
    }
    if (level === 5 || level === 6) {
      let timeoutError = null;
      try { await recorder.httpJson({ stageId: "CONTROLLED_SLOW_ABORT", caller: "native-ladder", pathname: "/slow", expectedServerInstance: instance, expectedSessionGeneration: "ladder-generation", timeoutMs: 20 }); } catch (error) { timeoutError = error; }
      assert.equal(timeoutError?.classification, "FETCH_ABORT_OR_TIMEOUT");
      recorder.markControlledFailure("CONTROLLED_SLOW_ABORT", { controlled_by_ladder: true });
      stage("CONTROLLED_SLOW_ABORT_COMPLETE");
      if (level === 5) {
        await slowSettled;
        await closeExactServer(exactServer, "HARNESS");
      } else {
        const closed = once(exactServer, "close");
        const response = await recorder.httpJson({ stageId: "STOP_AFTER_ABORT", caller: "native-ladder", method: "POST", pathname: "/stop", expectedServerInstance: instance, expectedSessionGeneration: "ladder-generation" });
        assert.equal(response.status, 202);
        stage("STOP_AFTER_ABORT_RESPONSE_CONSUMED");
        if (handlerCloses) { await closed; stage("HANDLER_CLOSE_CONFIRMED"); } else { await slowSettled; await closeExactServer(exactServer, "HARNESS"); }
      }
    }
  }
  stage("LADDER_COMPLETE");
} catch (error) {
  failure = error;
  stage("LADDER_JAVASCRIPT_FAILURE", { error_name: error?.name ?? null, error_message: String(error?.message ?? error).slice(0, 512), error_code: error?.code ?? null });
} finally {
  if (server?.listening) {
    try { await closeExactServer(server, "FINALLY"); } catch (error) { stage("FINALLY_CLOSE_FAILED", { error_message: String(error?.message ?? error).slice(0, 512) }); }
  }
  writeDurable(resultPath, { schema_version: "tsf_native_reproduction_ladder_result_v1", status: failure ? "FAIL" : "PASS", numeric_exit_code: failure ? 1 : 0, level, variant, process_id: process.pid, parent_process_id: process.ppid, last_completed_stage: events.at(-1)?.stage_id ?? null, recorded_at: new Date().toISOString() });
}
if (failure) throw failure;
process.stdout.write(`${JSON.stringify({ status: "PASS", level, variant, evidence_root: evidenceRoot })}\n`);
