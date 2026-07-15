import { createHash, randomBytes, randomUUID } from "node:crypto";
import { existsSync, readFileSync, statSync } from "node:fs";
import { spawn } from "node:child_process";
import path from "node:path";

const MAX_CHILD_OUTPUT = 2 * 1024 * 1024;

function hash(value) {
  return createHash("sha256").update(value).digest("hex");
}

function jsonHash(value) {
  return hash(JSON.stringify(value));
}

function closedObject(value, allowed, required) {
  if (!value || Array.isArray(value) || typeof value !== "object") {
    throw new Error("INVALID_REQUEST_SHAPE");
  }
  const unknown = Object.keys(value).filter((key) => !allowed.includes(key));
  if (unknown.length) throw new Error("UNKNOWN_FIELD");
  if (required.some((key) => !Object.hasOwn(value, key))) {
    throw new Error("MISSING_REQUIRED_FIELD");
  }
  return value;
}

function parseJsonFile(filePath) {
  return JSON.parse(readFileSync(filePath, "utf8").replace(/^\uFEFF/, ""));
}

function isPathInside(candidate, root) {
  const resolvedCandidate = path.resolve(candidate);
  const resolvedRoot = path.resolve(root);
  const prefix = resolvedRoot.endsWith(path.sep) ? resolvedRoot : `${resolvedRoot}${path.sep}`;
  return resolvedCandidate.startsWith(prefix);
}

function assertNoncanonicalPreview(preview) {
  const valid = preview?.schema_version === "tsf_hq_dispatch_route_preview_response_v1"
    && preview?.banner === "PREVIEW_ONLY_NOT_AUTHORITY"
    && preview?.record_kind === "hq_dispatch_route_preview"
    && preview?.artifact?.record_kind === "preview_artifact"
    && preview?.artifact?.mission_record === false
    && preview?.artifact?.queue_record === false
    && preview?.authority?.preview_only === true
    && preview?.authority?.mission_submission_enabled === false
    && preview?.authority?.mission_execution_enabled === false
    && preview?.authority?.queue_mutation_enabled === false;
  if (!valid) throw new Error("PREVIEW_ARTIFACT_NOT_NONCANONICAL_PREVIEW");
}

function previewProjection(preview, requestHash) {
  return {
    request_hash: requestHash,
    proposed_project: preview.proposed_project,
    proposed_worker_role: preview.proposed_worker_role,
    model_routing: preview.model_routing,
    classification: preview.classification,
    access_proposal: preview.access_proposal,
    route_explanation: preview.route_explanation,
    required_approvals: preview.required_approvals,
    clarifications: preview.clarifications,
    allowed_reads: preview.allowed_reads,
    allowed_writes: preview.allowed_writes,
    forbidden_actions: preview.forbidden_actions,
    stop_conditions: preview.stop_conditions,
    registry_sources: preview.registry_sources,
  };
}

function errorCode(error) {
  return error instanceof Error && /^[A-Z0-9_]+(?::.*)?$/.test(error.message)
    ? error.message.split(":", 1)[0]
    : "MISSION_RELAY_FAILED_CLOSED";
}

function processFailureCode(processResult) {
  const text = `${processResult?.stderr ?? ""}\n${processResult?.stdout ?? ""}`;
  const known = text.match(/\b(?:COMPLETE_RUNTIME_PATH_PLAN_REJECTED|CANONICAL_PREPARATION_REJECTED|FOREGROUND_CHILD_TIMEOUT|FOREGROUND_CHILD_OUTPUT_LIMIT|TIM_REQUIRED[A-Z0-9_]*)\b/);
  return known?.[0] ?? (Number(processResult?.code) === 0 ? "NO_ADMISSION_RECEIPT" : "CANONICAL_EXECUTOR_NONZERO");
}

export class HqMissionRelay {
  constructor({
    repositoryRoot,
    powershellExe,
    invokePreview,
    previewRoot = path.join(repositoryRoot, ".codex-local", "hq-dispatch", "preview"),
    testOnlyQueueRoot = "",
    executionAdapter = null,
    workerTimeoutSeconds = 180,
  }) {
    this.repositoryRoot = repositoryRoot;
    this.powershellExe = powershellExe;
    this.invokePreview = invokePreview;
    this.previewRoot = path.resolve(previewRoot);
    this.testOnlyQueueRoot = testOnlyQueueRoot;
    this.executionAdapter = executionAdapter;
    this.workerTimeoutSeconds = workerTimeoutSeconds;
    this.previews = new Map();
    this.submissions = new Map();
    this.missions = new Map();
    this.completedBindings = new Map();
    this.activeMissionId = null;
    this.activeChild = null;
    this.shuttingDown = false;
  }

  decoratePreview(preview, naturalRequest, sessionKey) {
    assertNoncanonicalPreview(preview);
    const requestHash = hash(naturalRequest.trim());
    const artifactPath = path.resolve(
      this.repositoryRoot,
      ...preview.artifact.relative_path.split("/"),
    );
    if (!isPathInside(artifactPath, this.previewRoot)) {
      throw new Error("PREVIEW_ARTIFACT_OUTSIDE_APPROVED_DIRECTORY");
    }
    const previewSha256 = hash(readFileSync(artifactPath));
    const submissionId = `hq-submission-${randomUUID()}`;
    const decorated = {
      ...preview,
      request_hash: requestHash,
      preview_sha256: previewSha256,
      submission_id: submissionId,
    };
    this.previews.set(preview.preview_id, {
      naturalRequest: naturalRequest.trim(),
      requestHash,
      previewSha256,
      artifactPath,
      projectionHash: jsonHash(previewProjection(preview, requestHash)),
      submissionId,
      sessionKey,
    });
    return decorated;
  }

  async submit(raw, sessionKey) {
    const input = closedObject(
      raw,
      ["natural_request", "preview_id", "preview_sha256", "request_hash", "intent", "submission_id"],
      ["natural_request", "preview_id", "preview_sha256", "request_hash", "intent", "submission_id"],
    );
    if (input.intent !== "CREATE_GOVERNED_MISSION") throw new Error("INVALID_OPERATOR_INTENT");
    if (typeof input.natural_request !== "string" || !input.natural_request.trim() || input.natural_request.length > 4000) {
      throw new Error("INVALID_NATURAL_REQUEST");
    }
    for (const field of ["preview_id", "preview_sha256", "request_hash", "submission_id"]) {
      if (typeof input[field] !== "string") throw new Error("INVALID_SUBMISSION_BINDING");
    }
    const contentHash = jsonHash(input);
    const prior = this.submissions.get(input.submission_id);
    if (prior) {
      if (prior.contentHash !== contentHash || prior.sessionKey !== sessionKey) throw new Error("SUBMISSION_REPLAY_CONTENT_MISMATCH");
      return prior.promise;
    }
    const promise = this.#submitNew(input, sessionKey).finally(() => {
      if (this.activeMissionId && this.missions.get(this.activeMissionId)?.terminal) {
        this.activeMissionId = null;
      }
    });
    this.submissions.set(input.submission_id, { contentHash, promise, sessionKey });
    return promise;
  }

  async #submitNew(input, sessionKey) {
    if (this.shuttingDown) throw new Error("SERVER_SHUTTING_DOWN");
    const binding = this.previews.get(input.preview_id);
    if (!binding || binding.submissionId !== input.submission_id || binding.sessionKey !== sessionKey) throw new Error("UNKNOWN_OR_CROSS_SESSION_PREVIEW");
    const requestHash = hash(input.natural_request.trim());
    if (requestHash !== input.request_hash || requestHash !== binding.requestHash) throw new Error("REQUEST_HASH_MISMATCH");
    if (input.preview_sha256 !== binding.previewSha256) throw new Error("PREVIEW_HASH_MISMATCH");
    if (!existsSync(binding.artifactPath) || hash(readFileSync(binding.artifactPath)) !== binding.previewSha256) {
      throw new Error("PREVIEW_ARTIFACT_STALE_OR_ALTERED");
    }
    if (!isPathInside(binding.artifactPath, this.previewRoot)) throw new Error("PREVIEW_ARTIFACT_OUTSIDE_APPROVED_DIRECTORY");
    const storedPreview = parseJsonFile(binding.artifactPath);
    assertNoncanonicalPreview(storedPreview);
    if (jsonHash(previewProjection(storedPreview, requestHash)) !== binding.projectionHash) {
      throw new Error("PREVIEW_ARTIFACT_PROJECTION_MISMATCH");
    }
    const recomputed = await this.invokePreview({ natural_request: input.natural_request.trim() });
    assertNoncanonicalPreview(recomputed);
    if (jsonHash(previewProjection(recomputed, requestHash)) !== binding.projectionHash) {
      throw new Error("RECOMPUTED_PREVIEW_MISMATCH");
    }
    if (storedPreview.classification !== "SAFE_LOCAL_MISSION") throw new Error("PREVIEW_NOT_SUBMITTABLE");

    const replayKey = jsonHash({ requestHash, projectionHash: binding.projectionHash });
    if (this.activeMissionId) {
      const active = this.missions.get(this.activeMissionId);
      if (active?.replayKey === replayKey) {
        return {
          ...active.status,
          duplicate_replay: {
            ...active.status.duplicate_replay,
            active_identical_submission_returned: true,
          },
        };
      }
      throw new Error("ONE_ACTIVE_MISSION_LIMIT");
    }
    const completedMissionId = this.completedBindings.get(replayKey);
    const completed = completedMissionId ? this.missions.get(completedMissionId) : null;
    if (completed?.terminal) {
      return {
        ...completed.status,
        duplicate_replay: {
          ...completed.status.duplicate_replay,
          completed_identical_submission_returned: true,
          canonical_terminal_source_reused: completed.status.source_path,
        },
      };
    }

    const missionId = `hq2-${Date.now().toString(36)}-${randomBytes(3).toString("hex")}`;
    this.activeMissionId = missionId;
    const record = {
      missionId,
      requestHash,
      previewId: input.preview_id,
      naturalRequest: input.natural_request.trim(),
      revision: 1,
      sessionKey,
      replayKey,
      events: [],
      terminal: false,
      status: this.#status("PREPARING", missionId, 1, {
        explanation: "Canonical Project Main Bot and durable mission preparation are running.",
        assurance: "CANONICAL_PREPARATION_PENDING",
      }),
    };
    this.missions.set(missionId, record);
    this.#event(record, record.status);
    try {
      const outcome = this.executionAdapter
        ? await this.executionAdapter({ missionId, missionRevision: 1, naturalRequest: record.naturalRequest })
        : await this.#prepareAndExecute({ missionId, missionRevision: 1, naturalRequest: record.naturalRequest });
      this.#applyOutcome(record, outcome);
    } catch (error) {
      record.terminal = true;
      record.status = this.shuttingDown
        ? this.#status("INTERRUPTED", missionId, 1, {
          sourcePath: record.preparation?.queue_record_path,
          runId: record.preparation?.run_id,
          explanation: "HQ Dispatch shutdown interrupted the owned foreground executor; no admission is inferred.",
          assurance: "LOCAL_SHUTDOWN_WITHOUT_ADMISSION",
          authority: this.#authorityProjection(),
          next_action: "Inspect canonical queue/lifecycle evidence before creating any new mission.",
        })
        : this.#status("FAILED", missionId, 1, {
          explanation: errorCode(error),
          assurance: "FAILED_CLOSED",
        });
      this.#event(record, record.status);
    }
    if (record.terminal) this.completedBindings.set(replayKey, missionId);
    return record.status;
  }

  async #prepareAndExecute({ missionId, missionRevision, naturalRequest }) {
    const wrapper = path.join(this.repositoryRoot, "tools", "hq-dispatch", "v1", "New-TsfHqDispatchGovernedMission.ps1");
    const args = ["-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", wrapper];
    if (this.testOnlyQueueRoot) args.push("-TestOnlyQueueRoot", this.testOnlyQueueRoot);
    const prepInput = {
      mission_id: missionId,
      mission_revision: missionRevision,
      natural_request: naturalRequest,
    };
    const preparedProcess = await this.#spawnOwned(this.powershellExe, args, JSON.stringify(prepInput), 60_000);
    if (preparedProcess.code !== 0) throw new Error("CANONICAL_PREPARATION_REJECTED");
    const preparation = JSON.parse(preparedProcess.stdout.trim().split(/\r?\n/).at(-1));
    const record = this.missions.get(missionId);
    if (record) {
      record.preparation = preparation;
      record.status = this.#status("QUEUED", missionId, missionRevision, {
        sourcePath: preparation.queue_record_path,
        runId: preparation.run_id,
        explanation: "Exactly one canonical queue document was prepared.",
        assurance: "CANONICAL_QUEUE_OBSERVED",
        route: preparation.route,
        access: preparation.access,
      });
      this.#event(record, record.status);
    }

    const executor = path.join(this.repositoryRoot, "tools", "Invoke-TsfMissionQueueForegroundExecutor.ps1");
    const execArgs = [
      "-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", executor,
      "-MissionPath", preparation.queue_record_path,
      "-QueueRoot", this.testOnlyQueueRoot || "fleet/missions",
      "-RunCanonicalAppServerWorker",
      "-WorkerTimeoutSeconds", String(this.workerTimeoutSeconds),
    ];
    if (this.testOnlyQueueRoot) execArgs.push("-TestOnlyAllowAlternateQueueRoot");
    if (record) {
      record.status = this.#status("DISPATCHING", missionId, missionRevision, {
        sourcePath: preparation.queue_record_path,
        runId: preparation.run_id,
        explanation: "The existing foreground queue executor is being invoked with fixed server-owned arguments.",
        assurance: "CANONICAL_EXECUTOR_ENTRYPOINT_BOUND",
        route: preparation.route,
        access: preparation.access,
      });
      this.#event(record, record.status);
    }
    const executing = this.#spawnOwned(this.powershellExe, execArgs, "", (this.workerTimeoutSeconds + 60) * 1000);
    if (record) {
      record.status = this.#status("RUNNING", missionId, missionRevision, {
        sourcePath: preparation.queue_record_path,
        runId: preparation.run_id,
        explanation: "Existing foreground queue executor owns the bounded app-server child.",
        assurance: "CANONICAL_EXECUTOR_INVOKED",
        route: preparation.route,
        access: preparation.access,
      });
      this.#event(record, record.status);
    }
    const processResult = await executing;
    const queueResult = existsSync(preparation.queue_result_path) ? parseJsonFile(preparation.queue_result_path) : null;
    const lifecycle = existsSync(preparation.lifecycle_result_path) ? parseJsonFile(preparation.lifecycle_result_path) : null;
    const adapter = existsSync(preparation.adapter_result_path) ? parseJsonFile(preparation.adapter_result_path) : null;
    const verifier = existsSync(preparation.verifier_result_path) ? parseJsonFile(preparation.verifier_result_path) : null;
    const workerResult = lifecycle?.worker_result_path && existsSync(lifecycle.worker_result_path) ? parseJsonFile(lifecycle.worker_result_path) : null;
    const durableResult = queueResult?.durable_result_path && existsSync(queueResult.durable_result_path) ? parseJsonFile(queueResult.durable_result_path) : null;
    return { preparation, processResult, queueResult, lifecycle, adapter, verifier, workerResult, durableResult };
  }

  #applyOutcome(record, outcome) {
    const { preparation, processResult = {}, queueResult, lifecycle, adapter, verifier, workerResult, durableResult } = outcome;
    record.preparation = preparation;
    record.outcome = outcome;
    if (verifier) {
      record.status = this.#status("VERIFYING", record.missionId, record.revision, {
        sourcePath: preparation.verifier_result_path,
        runId: preparation.run_id,
        explanation: "Canonical verifier result observed; admission is not yet inferred.",
        assurance: "CANONICAL_VERIFIER_RECORD",
        route: preparation.route,
        access: preparation.access,
        worker: this.#workerProjection(lifecycle, adapter, workerResult, durableResult),
        verifier: this.#verifierProjection(verifier, lifecycle, preparation.verifier_result_path),
      });
      this.#event(record, record.status);
    }
    if (lifecycle?.preservation_status) {
      record.status = this.#status("PRESERVING", record.missionId, record.revision, {
        sourcePath: lifecycle.preservation_packet_file ?? preparation.preservation_packet_path,
        runId: preparation.run_id,
        explanation: "Canonical lifecycle preservation record observed; admission remains terminal truth.",
        assurance: "CANONICAL_PRESERVATION_RECORD",
        route: preparation.route,
        access: preparation.access,
        worker: this.#workerProjection(lifecycle, adapter, workerResult, durableResult),
        verifier: this.#verifierProjection(verifier, lifecycle, preparation.verifier_result_path),
        preservation: this.#preservationProjection(lifecycle),
      });
      this.#event(record, record.status);
    }
    const admission = queueResult?.admission_receipt ?? null;
    if (admission && ["ADMITTED", "ADMITTED_WITH_CAVEATS"].includes(admission.status)) {
      const state = admission.status;
      record.terminal = true;
      record.status = this.#status(state, record.missionId, record.revision, {
        sourcePath: admission.receipt_file ?? admission.admission_receipt_path ?? queueResult.durable_result_path,
        runId: preparation.run_id,
        resultId: admission.result_id,
        explanation: "Canonical admission receipt is the terminal source of truth.",
        assurance: "CANONICAL_ADMISSION_RECEIPT",
        route: preparation.route,
        access: preparation.access,
        queue_state: queueResult.final_queue_state,
        worker: this.#workerProjection(lifecycle, adapter, workerResult, durableResult),
        verifier: this.#verifierProjection(verifier, lifecycle, preparation.verifier_result_path),
        preservation: this.#preservationProjection(lifecycle),
        admission: this.#admissionProjection(admission),
        result: this.#resultProjection(preparation, queueResult, durableResult),
        authority: this.#authorityProjection(),
        next_action: "Independent read-only audit of the local Milestone 2 commit.",
      });
      this.#event(record, record.status);
      return;
    }
    const timRequired = lifecycle?.terminal_status === "TIM_REQUIRED" || String(queueResult?.final_decision ?? "").startsWith("TIM_REQUIRED") || String(processResult.code) !== "0" && /TIM_REQUIRED/.test(`${JSON.stringify({ queueResult, lifecycle })}\n${processResult.stderr ?? ""}`);
    if (timRequired) {
      record.terminal = true;
      const kind = lifecycle?.approval_semantics === "APPROVAL_REQUIRED" ? "APPROVAL_REQUIRED" : "AUTHORITY_DECISION_REQUIRED";
      const evidencePath = preparation.lifecycle_result_path || preparation.queue_result_path;
      const evidenceHash = existsSync(evidencePath) ? hash(readFileSync(evidencePath)) : "0".repeat(64);
      record.timRequest = {
        schema_version: "tsf_hq_dispatch_tim_request_projection_v1",
        request_kind: kind,
        mission_id: record.missionId,
        mission_revision: record.revision,
        run_id: preparation.run_id,
        result_id: queueResult?.admission_receipt?.result_id ?? preparation.run_id,
        requested_operation: kind === "APPROVAL_REQUIRED" ? "EXACT_CANONICAL_APPROVAL" : "REVIEW_RUNTIME_AUTHORITY_OR_SERVICE_BLOCKER",
        exact_paths: preparation.access?.allowed_writes ?? [],
        access_level: preparation.access?.permission_mode ?? "READ_ONLY",
        network_scope: preparation.access?.control_plane_service_network_policy ?? "CODEX_SERVICE_ONLY",
        repository: this.repositoryRoot,
        worktree: this.repositoryRoot,
        reason: [...(lifecycle?.blocked_reasons ?? []), ...(queueResult?.blocked_reasons ?? [])].join("; ") || "Canonical runtime requested an operator decision.",
        expiry: parseJsonFile(preparation.mission_path).expires_at,
        usage: "SINGLE_USE",
        evidence_path: evidencePath,
        evidence_sha256: evidenceHash,
        requested_action: kind === "APPROVAL_REQUIRED" ? "APPROVE_EXACT_REQUEST or DENY_REQUEST" : "Resolve the bounded authority/service blocker through a new governed run.",
        authority_not_included: ["merge", "push", "deploy", "production", "plugins", "credentials", "product repositories"],
        original_run_stopped: true,
      };
      record.status = this.#status("TIM_REQUIRED", record.missionId, record.revision, {
        sourcePath: evidencePath,
        runId: preparation.run_id,
        explanation: "The original run is terminal and will never be silently resumed.",
        assurance: "CANONICAL_TERMINAL_EVIDENCE",
        route: preparation.route,
        access: preparation.access,
        worker: this.#workerProjection(lifecycle, adapter, workerResult, durableResult),
        verifier: this.#verifierProjection(verifier, lifecycle, preparation.verifier_result_path),
        preservation: this.#preservationProjection(lifecycle),
        result: this.#resultProjection(preparation, queueResult, durableResult),
        tim_request: record.timRequest,
        authority: this.#authorityProjection(),
        next_action: record.timRequest.requested_action,
      });
      this.#event(record, record.status);
      return;
    }
    record.terminal = true;
    const rejectionSource = queueResult && existsSync(preparation.queue_result_path)
      ? preparation.queue_result_path
      : lifecycle && existsSync(preparation.lifecycle_result_path)
        ? preparation.lifecycle_result_path
        : preparation.queue_record_path;
    record.status = this.#status("REJECTED", record.missionId, record.revision, {
      sourcePath: rejectionSource,
      runId: preparation.run_id,
      explanation: `No successful canonical admission receipt exists; ${processFailureCode(processResult)}.`,
      assurance: "NO_ADMISSION_RECEIPT",
      route: preparation.route,
      access: preparation.access,
      queue_state: queueResult?.final_queue_state ?? preparation.queue_state ?? "inbox",
      worker: this.#workerProjection(lifecycle, adapter, workerResult, durableResult),
      verifier: this.#verifierProjection(verifier, lifecycle, preparation.verifier_result_path),
      preservation: this.#preservationProjection(lifecycle),
      result: this.#resultProjection(preparation, queueResult, durableResult),
      authority: this.#authorityProjection(),
      next_action: "Inspect the canonical lifecycle and verifier evidence; do not treat this run as accepted.",
    });
    this.#event(record, record.status);
  }

  getMission(missionId) {
    const record = this.missions.get(missionId);
    if (!record) throw new Error("MISSION_NOT_FOUND");
    return record.status;
  }

  getEvents(missionId) {
    const record = this.missions.get(missionId);
    if (!record) throw new Error("MISSION_NOT_FOUND");
    return { schema_version: "tsf_hq_dispatch_mission_events_v1", mission_id: missionId, events: record.events };
  }

  async #spawnOwned(executable, args, input, timeoutMs) {
    if (this.shuttingDown) throw new Error("SERVER_SHUTTING_DOWN");
    return new Promise((resolve, reject) => {
      const child = spawn(executable, args, {
        cwd: this.repositoryRoot,
        detached: false,
        shell: false,
        windowsHide: true,
        stdio: ["pipe", "pipe", "pipe"],
      });
      this.activeChild = child;
      let resolveChildClosed;
      this.activeChildClosed = new Promise((resolve) => { resolveChildClosed = resolve; });
      const stdout = [];
      const stderr = [];
      let bytes = 0;
      let settled = false;
      let abortError = null;
      const finish = (fn, value) => {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        if (this.activeChild === child) this.activeChild = null;
        if (this.activeChildClosed) this.activeChildClosed = null;
        fn(value);
      };
      const timer = setTimeout(() => {
        abortError = new Error("FOREGROUND_CHILD_TIMEOUT");
        child.kill();
      }, timeoutMs);
      for (const [stream, target] of [[child.stdout, stdout], [child.stderr, stderr]]) {
        stream.on("data", (chunk) => {
          bytes += chunk.byteLength;
          if (bytes > MAX_CHILD_OUTPUT) {
            abortError = new Error("FOREGROUND_CHILD_OUTPUT_LIMIT");
            child.kill();
          } else target.push(chunk);
        });
      }
      child.on("error", () => {
        resolveChildClosed();
        finish(reject, new Error("FOREGROUND_CHILD_UNAVAILABLE"));
      });
      child.on("close", (code, signal) => {
        resolveChildClosed();
        if (abortError) {
          finish(reject, abortError);
          return;
        }
        finish(resolve, {
          code,
          signal,
          stdout: Buffer.concat(stdout).toString("utf8"),
          stderr: Buffer.concat(stderr).toString("utf8"),
          child_exited: true,
          no_orphan_process: null,
        });
      });
      child.stdin.on("error", () => {});
      child.stdin.end(input, "utf8");
    });
  }

  async shutdown() {
    this.shuttingDown = true;
    const record = this.activeMissionId ? this.missions.get(this.activeMissionId) : null;
    if (record && !record.terminal) {
      record.terminal = true;
      record.status = this.#status("INTERRUPTED", record.missionId, record.revision, {
        sourcePath: record.preparation?.queue_record_path,
        runId: record.preparation?.run_id,
        explanation: "HQ Dispatch shutdown interrupted the owned foreground process; no success, verification, or admission is inferred.",
        assurance: "LOCAL_SHUTDOWN_WITHOUT_ADMISSION",
        next_action: "Inspect canonical queue/lifecycle evidence before creating any new mission.",
      });
      this.#event(record, record.status);
    }
    const child = this.activeChild;
    if (child && !child.killed) child.kill();
    if (this.activeChildClosed) {
      await Promise.race([
        this.activeChildClosed,
        new Promise((resolve) => setTimeout(resolve, 5000)),
      ]);
    }
    this.previews.clear();
    return { child_exited: !this.activeChild, interrupted_mission_id: record?.missionId ?? null };
  }

  #event(record, status) {
    record.events.push({
      state: status.state,
      timestamp: status.timestamp,
      canonical_source_record: status.canonical_source_record,
      source_path: status.source_path,
      mission_id: status.mission_id,
      mission_revision: status.mission_revision,
      run_id: status.run_id,
      assurance: status.assurance,
      explanation: status.explanation,
    });
  }

  #status(state, missionId, revision, fields = {}) {
    return {
      schema_version: "tsf_hq_dispatch_mission_status_v1",
      state,
      timestamp: new Date().toISOString(),
      canonical_source_record: fields.sourcePath ? path.basename(fields.sourcePath) : "pending canonical record",
      source_path: fields.sourcePath ?? "",
      mission_id: missionId,
      mission_revision: revision,
      run_id: fields.runId ?? null,
      result_id: fields.resultId ?? null,
      assurance: fields.assurance ?? "PROJECTION_ONLY",
      explanation: fields.explanation ?? "Canonical state projection.",
      route: fields.route ?? null,
      access: fields.access ?? null,
      queue_state: fields.queue_state ?? null,
      worker: fields.worker ?? null,
      verifier: fields.verifier ?? null,
      preservation: fields.preservation ?? null,
      admission: fields.admission ?? null,
      result: fields.result ?? null,
      tim_request: fields.tim_request ?? null,
      authority: fields.authority ?? this.#authorityProjection(),
      caveats: fields.caveats ?? [],
      duplicate_replay: { duplicate_execution_prevented: true, response_replay_bound: true },
      next_action: fields.next_action ?? "Wait for the next canonical record.",
      projection_only: true,
    };
  }

  #workerProjection(lifecycle, adapter, workerResult, durableResult) {
    return {
      status: lifecycle?.worker_status ?? "NOT_OBSERVED",
      thread_id: adapter?.thread_id ?? null,
      turn_id: adapter?.turn_id ?? null,
      model: adapter?.observed_model ?? null,
      effort: adapter?.effective_effort ?? adapter?.canonical_resolved_effort ?? null,
      child_exited: adapter?.child_exited ?? null,
      no_orphan_process: adapter?.no_orphan_process ?? null,
      changed_paths: durableResult?.files_changed ?? workerResult?.files_touched ?? [],
      created_paths: workerResult?.files_created ?? [],
      tests: durableResult?.tests ?? workerResult?.tests ?? [],
    };
  }

  #verifierProjection(verifier, lifecycle, verifierPath) {
    return { identity: "canonical-kernel-postrun", verdict: verifier?.verdict ?? lifecycle?.verifier_verdict ?? "NOT_OBSERVED", verified: verifier?.verified ?? false, result_path: verifierPath ?? null, result_sha256: this.#safeFileHash(verifierPath) };
  }

  #preservationProjection(lifecycle) {
    return { status: lifecycle?.preservation_status ?? "NOT_OBSERVED", packet_path: lifecycle?.preservation_packet_file ?? null, packet_sha256: this.#safeFileHash(lifecycle?.preservation_packet_file), manifest_path: lifecycle?.preservation_manifest_path ?? null, manifest_sha256: this.#safeFileHash(lifecycle?.preservation_manifest_path), evidence_preserved: lifecycle?.evidence_preserved ?? false };
  }

  #admissionProjection(admission) {
    const receiptPath = admission.receipt_file ?? admission.admission_receipt_path ?? null;
    return {
      verdict: admission.status,
      reasons: admission.reasons ?? [],
      caveats: admission.caveats ?? [],
      receipt_id: admission.receipt_id ?? null,
      receipt_identity_sha256: admission.receipt_identity_sha256 ?? null,
      admission_decision_sha256: admission.admission_decision_sha256 ?? null,
      receipt_path: receiptPath,
      receipt_sha256: admission.receipt_sha256 ?? this.#safeFileHash(receiptPath),
    };
  }

  #authorityProjection() {
    return { granted: [], explicitly_denied: ["approval", "merge", "push", "deployment", "production", "plugins", "credentials", "product repository access"] };
  }

  #resultProjection(preparation, queueResult, durableResult) {
    return {
      mission_sha256: preparation?.mission_sha256 ?? null,
      queue_document_sha256: preparation?.queue_document_sha256 ?? null,
      durable_result_path: queueResult?.durable_result_path ?? null,
      durable_result_sha256: this.#safeFileHash(queueResult?.durable_result_path),
      tests: durableResult?.tests ?? [],
    };
  }

  #safeFileHash(filePath) {
    if (!filePath || !isPathInside(filePath, this.repositoryRoot) || !existsSync(filePath)) return null;
    try {
      if (!statSync(filePath).isFile()) return null;
      return hash(readFileSync(filePath));
    } catch {
      return null;
    }
  }
}
