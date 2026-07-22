import { createHash, randomBytes, randomUUID } from "node:crypto";
import { existsSync, readFileSync, statSync } from "node:fs";
import { spawn } from "node:child_process";
import path from "node:path";

const MAX_CHILD_OUTPUT = 2 * 1024 * 1024;
const M3_REAL_INTERRUPTION_FIXTURE = "TSF_HQ_DISPATCH_M3_REAL_INTERRUPTION_FIXTURE_V1";
const M3_REAL_INTERRUPTION_ROOT = path.join(".codex-local", "fixtures", "hq-dispatch-m3-real-interruption-v1");
const m3RealInterruptionBarriers = new WeakSet();
const m3RealInterruptionCapabilities = new WeakMap();

export function createM3RealInterruptionBarrier({
  repositoryRoot,
  fixtureType,
  fixtureRoot,
  testRunIdentity,
  access,
  inMemoryCapability,
  onOwnedExecutor,
  onOwnedCleanup,
  timeoutMs = 180_000,
}) {
  const resolvedRepository = path.resolve(repositoryRoot ?? "");
  const expectedRoot = path.resolve(resolvedRepository, M3_REAL_INTERRUPTION_ROOT);
  if (fixtureType !== M3_REAL_INTERRUPTION_FIXTURE) throw new Error("M3_INTERRUPTION_FIXTURE_IDENTITY_REJECTED");
  if (path.resolve(fixtureRoot ?? "") !== expectedRoot) throw new Error("M3_INTERRUPTION_FIXTURE_ROOT_REJECTED");
  if (!/^[a-z0-9][a-z0-9-]{7,63}$/.test(String(testRunIdentity ?? ""))) throw new Error("M3_INTERRUPTION_TEST_RUN_IDENTITY_REJECTED");
  if (!inMemoryCapability || typeof inMemoryCapability !== "object") throw new Error("M3_INTERRUPTION_IN_MEMORY_CAPABILITY_REQUIRED");
  if (!access || access.permission_mode !== "READ_ONLY"
      || access.worker_tool_network_policy !== "DISABLED"
      || access.control_plane_service_network_policy !== "CODEX_SERVICE_ONLY"
      || !Array.isArray(access.allowed_writes) || access.allowed_writes.length !== 0
      || path.resolve(access.repository ?? "") !== resolvedRepository
      || access.product_repository_targeted !== false) {
    throw new Error("M3_INTERRUPTION_FIXTURE_ACCESS_REJECTED");
  }
  if (typeof onOwnedExecutor !== "function") throw new Error("M3_INTERRUPTION_OWNED_EXECUTOR_HOOK_REQUIRED");
  if (typeof onOwnedCleanup !== "function") throw new Error("M3_INTERRUPTION_OWNED_CLEANUP_HOOK_REQUIRED");
  if (!Number.isInteger(timeoutMs) || timeoutMs < 25 || timeoutMs > 240_000) throw new Error("M3_INTERRUPTION_TIMEOUT_REJECTED");
  const capabilityIdentitySha256 = hash(randomBytes(32));
  const barrier = Object.freeze({
    fixture_type: M3_REAL_INTERRUPTION_FIXTURE,
    fixture_root: expectedRoot,
    test_run_identity: testRunIdentity,
    test_run_root: path.join(expectedRoot, testRunIdentity),
    timeout_ms: timeoutMs,
    capability_identity_sha256: capabilityIdentitySha256,
    activate(suppliedCapability, context) {
      if (suppliedCapability !== inMemoryCapability) throw new Error("M3_INTERRUPTION_IN_MEMORY_CAPABILITY_REJECTED");
      return onOwnedExecutor(context);
    },
    cleanup(suppliedCapability) {
      if (suppliedCapability !== inMemoryCapability) throw new Error("M3_INTERRUPTION_IN_MEMORY_CAPABILITY_REJECTED");
      return onOwnedCleanup();
    },
  });
  m3RealInterruptionBarriers.add(barrier);
  m3RealInterruptionCapabilities.set(barrier, inMemoryCapability);
  return barrier;
}

function hash(value) {
  return createHash("sha256").update(value).digest("hex");
}

function jsonHash(value) {
  return hash(JSON.stringify(value));
}

function exactResponseSemantic(contract) {
  return {
    validation_mode: contract.validation_mode,
    normalization_version: contract.normalization_version,
    expected_literal: contract.expected_literal,
    expected_literal_sha256: contract.expected_literal_sha256,
    case_sensitive: contract.case_sensitive,
    whitespace_sensitive: contract.whitespace_sensitive,
    executable_interpretation: contract.executable_interpretation,
    source_requirement_kind: contract.source_requirement?.kind,
    source_request_sha256: contract.source_requirement?.request_sha256,
  };
}

function assertExactResponseContract(contract, {
  requestHash,
  previewId,
  previewArtifactSha256 = null,
  missionId = null,
  missionRevision = null,
} = {}) {
  if (contract === null || contract === undefined) return null;
  const literal = contract.expected_literal;
  const semantic = exactResponseSemantic(contract);
  const previewIdentity = {
    preview_id: previewId,
    source_request_sha256: requestHash,
    semantic_contract_sha256: contract.semantic_contract_sha256,
  };
  const valid = contract.schema_version === "tsf_exact_literal_response_contract_v1"
    && contract.validation_mode === "EXACT_LITERAL_V1"
    && contract.normalization_version === "ASCII_TOKEN_IDENTITY_V1"
    && typeof literal === "string"
    && /^[A-Z][A-Z0-9_]{0,127}$/.test(literal)
    && contract.expected_literal_sha256 === hash(literal)
    && contract.semantic_contract_sha256 === jsonHash(semantic)
    && contract.case_sensitive === true
    && contract.whitespace_sensitive === true
    && contract.executable_interpretation === false
    && contract.source_requirement?.kind === "EXPLICIT_RETURN_EXACTLY_V1"
    && contract.source_requirement?.request_sha256 === requestHash
    && contract.source_requirement?.natural_request_persisted_in_preview === false
    && contract.preview_binding?.preview_id === previewId
    && contract.preview_binding?.preview_contract_sha256 === jsonHash(previewIdentity)
    && contract.preview_binding?.preview_artifact_sha256 === previewArtifactSha256
    && contract.mission_binding?.mission_id === missionId
    && contract.mission_binding?.mission_revision === missionRevision;
  if (!valid) throw new Error("EXACT_RESPONSE_CONTRACT_INVALID");
  return contract;
}

function bindPreviewArtifact(contract, previewArtifactSha256) {
  if (!contract) return null;
  const bound = structuredClone(contract);
  bound.preview_binding.preview_artifact_sha256 = previewArtifactSha256;
  return bound;
}

function reviewedContractForm(contract) {
  if (!contract) return null;
  const reviewed = structuredClone(contract);
  reviewed.mission_binding = { mission_id: null, mission_revision: null };
  return reviewed;
}

function assertContractContinuation(reviewed, missionBound, missionId, missionRevision) {
  if (!reviewed && !missionBound) return;
  if (!reviewed || !missionBound) throw new Error("EXACT_RESPONSE_CONTRACT_SUBSTITUTED_OR_MISSING");
  assertExactResponseContract(reviewed, {
    requestHash: reviewed.source_requirement?.request_sha256,
    previewId: reviewed.preview_binding?.preview_id,
    previewArtifactSha256: reviewed.preview_binding?.preview_artifact_sha256,
  });
  assertExactResponseContract(missionBound, {
    requestHash: reviewed.source_requirement.request_sha256,
    previewId: reviewed.preview_binding.preview_id,
    previewArtifactSha256: reviewed.preview_binding.preview_artifact_sha256,
    missionId,
    missionRevision,
  });
  for (const field of ["expected_literal", "expected_literal_sha256", "semantic_contract_sha256", "validation_mode", "normalization_version"]) {
    if (missionBound[field] !== reviewed[field]) throw new Error("EXACT_RESPONSE_CONTRACT_SUBSTITUTED_OR_MISSING");
  }
}

function responseContentHash(value) {
  const names = [
    "mission_id", "mission_revision", "run_id", "result_id",
    "tim_required_request_id", "request_evidence_sha256", "response_id",
    "response_type", "operator_confirmation", "response_payload",
  ];
  const parts = names.map((name) => {
    const text = value[name] === null || value[name] === undefined ? "" : String(value[name]);
    return `${name}:${Buffer.byteLength(text, "utf8")}:${text}`;
  });
  return hash(`${parts.join("\n")}\n`);
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
    result_validation_mode: preview.result_validation_mode,
    exact_response_contract: preview.exact_response_contract ? {
      ...exactResponseSemantic(preview.exact_response_contract),
      semantic_contract_sha256: preview.exact_response_contract.semantic_contract_sha256,
    } : null,
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
    testOnlyInitialTimKind = "NONE",
    executionAdapter = null,
    responseAdapter = null,
    workerTimeoutSeconds = 180,
    onChildStart = null,
    onChildExit = null,
    onMissionChange = null,
    onInterrupted = null,
    terminateOwnedChild = null,
    testOnlyInterruptionBarrier = null,
  }) {
    this.repositoryRoot = repositoryRoot;
    this.powershellExe = powershellExe;
    this.invokePreview = invokePreview;
    this.previewRoot = path.resolve(previewRoot);
    this.testOnlyQueueRoot = testOnlyQueueRoot;
    this.testOnlyInitialTimKind = testOnlyInitialTimKind;
    this.executionAdapter = executionAdapter;
    this.responseAdapter = responseAdapter;
    this.workerTimeoutSeconds = workerTimeoutSeconds;
    this.onChildStart = onChildStart;
    this.onChildExit = onChildExit;
    this.onMissionChange = onMissionChange;
    this.onInterrupted = onInterrupted;
    this.terminateOwnedChild = terminateOwnedChild;
    if (testOnlyInterruptionBarrier && !m3RealInterruptionBarriers.has(testOnlyInterruptionBarrier)) {
      throw new Error("M3_INTERRUPTION_IN_MEMORY_CAPABILITY_REJECTED");
    }
    this.testOnlyInterruptionBarrier = testOnlyInterruptionBarrier;
    this.previews = new Map();
    this.submissions = new Map();
    this.missions = new Map();
    this.responses = new Map();
    this.recoveries = new Map();
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
    const exactResponseContract = bindPreviewArtifact(preview.exact_response_contract, previewSha256);
    assertExactResponseContract(exactResponseContract, {
      requestHash,
      previewId: preview.preview_id,
      previewArtifactSha256: previewSha256,
    });
    const submissionId = `hq-submission-${randomUUID()}`;
    const decorated = {
      ...preview,
      exact_response_contract: exactResponseContract,
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
      exactResponseContract,
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
      const existing = await prior.promise;
      return { ...existing, operator_message: "IDEMPOTENT_REPLAY" };
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
    const storedContract = bindPreviewArtifact(storedPreview.exact_response_contract, binding.previewSha256);
    assertExactResponseContract(storedContract, {
      requestHash,
      previewId: input.preview_id,
      previewArtifactSha256: binding.previewSha256,
    });
    if (jsonHash(storedContract) !== jsonHash(binding.exactResponseContract)) throw new Error("EXACT_RESPONSE_CONTRACT_STALE_OR_SUBSTITUTED");
    if (jsonHash(previewProjection(storedPreview, requestHash)) !== binding.projectionHash) {
      throw new Error("PREVIEW_ARTIFACT_PROJECTION_MISMATCH");
    }
    const recomputed = await this.invokePreview({ natural_request: input.natural_request.trim() });
    assertNoncanonicalPreview(recomputed);
    const recomputedContract = bindPreviewArtifact(recomputed.exact_response_contract, hash(readFileSync(path.resolve(this.repositoryRoot, ...recomputed.artifact.relative_path.split("/")))));
    if ((recomputedContract?.semantic_contract_sha256 ?? null) !== (binding.exactResponseContract?.semantic_contract_sha256 ?? null)
        || (recomputedContract?.expected_literal_sha256 ?? null) !== (binding.exactResponseContract?.expected_literal_sha256 ?? null)
        || (recomputedContract && recomputedContract.source_requirement?.request_sha256 !== requestHash)) {
      throw new Error("RECOMPUTED_EXACT_RESPONSE_CONTRACT_MISMATCH");
    }
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
          operator_message: "EXISTING_ACTIVE_MISSION",
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
        operator_message: "EXISTING_COMPLETED_MISSION",
      };
    }

    const missionId = `hq2-${Date.now().toString(36)}-${randomBytes(3).toString("hex")}`;
    this.activeMissionId = missionId;
    const record = {
      missionId,
      requestHash,
      previewId: input.preview_id,
      naturalRequest: input.natural_request.trim(),
      responseContract: binding.exactResponseContract,
      reviewedResponseContract: binding.exactResponseContract,
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
        ? await this.executionAdapter({ missionId, missionRevision: 1, naturalRequest: record.naturalRequest, exactResponseContract: record.responseContract })
        : await this.#prepareAndExecute({
          missionId,
          missionRevision: 1,
          naturalRequest: record.naturalRequest,
          reviewedExactResponseContract: record.responseContract,
          previewId: input.preview_id,
          previewSha256: binding.previewSha256,
          requestHash,
          submissionId: input.submission_id,
          forceNoWorkerLifecycle: this.testOnlyInitialTimKind !== "NONE",
        });
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
    if (record.terminal && this.onMissionChange) this.onMissionChange(null);
    return record.status;
  }

  async #prepareAndExecute({
    missionId,
    missionRevision,
    naturalRequest,
    reviewedExactResponseContract = null,
    previewId = null,
    previewSha256 = null,
    requestHash = null,
    submissionId = null,
    revisionInput = null,
    approvalLedgerPath = "",
    forceNoWorkerLifecycle = false,
  }) {
    const wrapper = path.join(this.repositoryRoot, "tools", "hq-dispatch", "v1", "New-TsfHqDispatchGovernedMission.ps1");
    const args = ["-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", wrapper];
    if (this.testOnlyQueueRoot) {
      args.push("-TestOnlyQueueRoot", this.testOnlyQueueRoot, "-UnsupportedDevelopmentMode");
      if (!revisionInput && this.testOnlyInitialTimKind !== "NONE") {
        args.push("-TestOnlyInitialTimKind", this.testOnlyInitialTimKind);
      }
    }
    const prepInput = revisionInput ?? {
      mission_id: missionId,
      mission_revision: missionRevision,
      natural_request: naturalRequest,
      preview_id: previewId,
      preview_sha256: previewSha256,
      request_hash: requestHash,
      submission_id: submissionId,
      reviewed_exact_response_contract: reviewedExactResponseContract,
    };
    const preparedProcess = await this.#spawnOwned(this.powershellExe, args, JSON.stringify(prepInput), 60_000);
    if (preparedProcess.code !== 0) throw new Error("CANONICAL_PREPARATION_REJECTED");
    const preparation = JSON.parse(preparedProcess.stdout.trim().split(/\r?\n/).at(-1));
    const record = this.missions.get(missionId);
    if (record) {
      record.preparation = preparation;
      record.responseContract = preparation.exact_response_contract ?? null;
      if (this.onMissionChange) {
        this.onMissionChange({
          mission_id: missionId,
          mission_revision: missionRevision,
          run_id: preparation.run_id,
          result_id: preparation.run_id,
          queue_record_path: preparation.queue_record_path,
        });
      }
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
      "-WorkerTimeoutSeconds", String(this.workerTimeoutSeconds),
    ];
    execArgs.push(forceNoWorkerLifecycle ? "-TestOnlyNoWorkerLifecycle" : "-RunCanonicalAppServerWorker");
    if (approvalLedgerPath) execArgs.push("-ApprovalLedgerPath", approvalLedgerPath);
    if (this.testOnlyQueueRoot) execArgs.push("-TestOnlyAllowAlternateQueueRoot", "-UnsupportedDevelopmentMode");
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
    const executing = this.#spawnOwned(this.powershellExe, execArgs, "", (this.workerTimeoutSeconds + 60) * 1000, {
      mission_id: missionId,
      mission_revision: missionRevision,
      run_id: preparation.run_id,
      result_id: preparation.run_id,
      preparation,
    });
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
    const mission = preparation?.mission_path && existsSync(preparation.mission_path) ? parseJsonFile(preparation.mission_path) : null;
    return { preparation, processResult, queueResult, lifecycle, adapter, verifier, workerResult, durableResult, mission };
  }

  #applyOutcome(record, outcome) {
    const { preparation, processResult = {}, queueResult, lifecycle, adapter, verifier, workerResult, durableResult, mission } = outcome;
    this.#assertOutcomeIdentity(record, outcome);
    if (mission?.exact_response_contract !== undefined) record.responseContract = mission.exact_response_contract;
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
      const canonicalRequest = lifecycle?.tim_required_request;
      if (!canonicalRequest || canonicalRequest.schema_version !== "tsf_tim_required_request_v1") {
        throw new Error("CANONICAL_TIM_REQUEST_MISSING");
      }
      if (canonicalRequest.mission_id !== record.missionId
          || Number(canonicalRequest.mission_revision) !== record.revision
          || canonicalRequest.run_id !== preparation.run_id
          || canonicalRequest.result_id !== preparation.run_id
          || !canonicalRequest.original_run_terminal
          || canonicalRequest.worker_active
          || canonicalRequest.app_server_child_active) {
        throw new Error("CANONICAL_TIM_REQUEST_BINDING_INVALID");
      }
      if (!["APPROVAL_REQUIRED", "CLARIFICATION_REQUIRED", "AUTHORITY_DECISION_REQUIRED"].includes(canonicalRequest.request_kind)
          || !Array.isArray(canonicalRequest.response_types)
          || canonicalRequest.response_types.length === 0) {
        throw new Error("CANONICAL_TIM_REQUEST_KIND_INVALID");
      }
      record.terminal = true;
      const evidencePath = preparation.lifecycle_result_path || preparation.queue_result_path;
      if (!existsSync(evidencePath)) throw new Error("CANONICAL_TIM_EVIDENCE_MISSING");
      const evidenceHash = hash(readFileSync(evidencePath));
      const responseId = `hq-response-${randomUUID()}`;
      record.timRequest = {
        schema_version: "tsf_hq_dispatch_tim_request_projection_v1",
        request_id: canonicalRequest.request_id,
        request_kind: canonicalRequest.request_kind,
        mission_id: canonicalRequest.mission_id,
        mission_revision: canonicalRequest.mission_revision,
        run_id: canonicalRequest.run_id,
        result_id: canonicalRequest.result_id,
        response_id: responseId,
        response_types: [...canonicalRequest.response_types],
        requested_operation: canonicalRequest.operation,
        exact_paths: [...canonicalRequest.exact_paths],
        access_level: canonicalRequest.access_level,
        network_scope: { ...canonicalRequest.network_scope },
        repository: canonicalRequest.repository,
        worktree: canonicalRequest.worktree,
        surface: canonicalRequest.surface,
        model: canonicalRequest.model,
        reason: canonicalRequest.reason,
        question: canonicalRequest.question,
        expiry: canonicalRequest.expires_at,
        usage: { ...canonicalRequest.usage_limit },
        evidence_path: evidencePath,
        evidence_sha256: evidenceHash,
        requested_action: canonicalRequest.response_types.join(" or "),
        authority_not_included: [...canonicalRequest.authority_not_included],
        original_run_terminal: true,
        prior_worker_resumed: false,
      };
      record.timCanonicalRequest = canonicalRequest;
      record.timResponseId = responseId;
      record.originalTimStatus = null;
      record.status = this.#status("TIM_REQUIRED", record.missionId, record.revision, {
        sourcePath: evidencePath,
        runId: preparation.run_id,
        resultId: canonicalRequest.result_id,
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
      record.originalTimStatus = structuredClone(record.status);
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

  async respond(raw, sessionKey) {
    const fields = [
      "mission_id", "mission_revision", "run_id", "result_id",
      "tim_required_request_id", "request_evidence_sha256", "response_id",
      "response_type", "operator_confirmation", "response_payload",
    ];
    const input = closedObject(raw, fields, fields);
    const record = this.missions.get(input.mission_id);
    if (!record) throw new Error("MISSION_NOT_FOUND");
    if (record.sessionKey !== sessionKey) throw new Error("CROSS_SESSION_TIM_RESPONSE");
    const request = record.timRequest;
    if (!request) throw new Error("MISSION_HAS_NO_CANONICAL_TIM_REQUEST");
    if (Number(input.mission_revision) !== Number(request.mission_revision)
        || input.run_id !== request.run_id
        || input.result_id !== request.result_id
        || input.tim_required_request_id !== request.request_id
        || input.request_evidence_sha256 !== request.evidence_sha256
        || input.response_id !== request.response_id) {
      throw new Error("TIM_RESPONSE_BINDING_MISMATCH");
    }
    if (Date.now() > Date.parse(request.expiry)) throw new Error("TIM_REQUIRED_REQUEST_EXPIRED");
    if (!existsSync(request.evidence_path) || hash(readFileSync(request.evidence_path)) !== request.evidence_sha256) {
      throw new Error("TIM_REQUIRED_REQUEST_EVIDENCE_MISMATCH");
    }
    const terminal = parseJsonFile(request.evidence_path);
    const canonical = terminal.tim_required_request;
    if (terminal.terminal_status !== "TIM_REQUIRED" || terminal.final_decision !== "TIM_REQUIRED"
        || terminal.mission_id !== input.mission_id
        || Number(terminal.mission_revision) !== Number(input.mission_revision)
        || terminal.run_id !== input.run_id || terminal.result_id !== input.result_id
        || canonical?.request_id !== input.tim_required_request_id
        || canonical?.superseded || canonical?.invalidated
        || !canonical?.original_run_terminal || canonical?.worker_active || canonical?.app_server_child_active) {
      throw new Error("TIM_REQUIRED_TERMINAL_REVALIDATION_FAILED");
    }
    if (!request.response_types.includes(input.response_type)) throw new Error("TIM_RESPONSE_TYPE_INCOMPATIBLE_WITH_REQUEST");
    if (typeof input.operator_confirmation !== "string"
        || !(input.response_payload === null || typeof input.response_payload === "string")) {
      throw new Error("TIM_RESPONSE_PAYLOAD_INVALID");
    }
    const expectedPhrase = {
      APPROVE_EXACT_REQUEST: "APPROVE EXACT REQUEST",
      DENY_REQUEST: "DENY REQUEST",
      PROVIDE_CLARIFICATION: "PROVIDE CLARIFICATION",
    }[input.response_type];
    if (input.operator_confirmation !== expectedPhrase) throw new Error("TIM_RESPONSE_CONFIRMATION_MISMATCH");
    if (input.response_type === "APPROVE_EXACT_REQUEST" && input.response_payload !== null) throw new Error("APPROVAL_RESPONSE_PAYLOAD_PROHIBITED");
    if (input.response_type === "DENY_REQUEST" && input.response_payload !== null
        && (input.response_payload.length > 500 || input.response_payload.includes("\0"))) throw new Error("DENIAL_REASON_INVALID");
    if (input.response_type === "PROVIDE_CLARIFICATION") {
      if (!input.response_payload?.trim() || input.response_payload.length > 2000 || input.response_payload.includes("\0")) throw new Error("CLARIFICATION_INVALID");
      if (/(-----BEGIN [A-Z ]*PRIVATE KEY-----|\bAKIA[0-9A-Z]{16}\b|\b(?:sk|ghp|github_pat)-?[A-Za-z0-9_-]{16,}\b|\b(?:password|passwd|secret|token|api[_-]?key)\s*[:=])/i.test(input.response_payload)) throw new Error("CLARIFICATION_SECRET_LIKE_REJECTED");
      if (/(\bcmd\.exe\b|\bpowershell(?:\.exe)?\b|\bbash\b|\bsh\s+-c\b|Invoke-Expression|Start-Process|\$\(|`[^`]+`|<script\b)/i.test(input.response_payload)) throw new Error("CLARIFICATION_EXECUTABLE_CONTENT_REJECTED");
    }
    const contentHash = responseContentHash(input);
    const prior = this.responses.get(input.response_id);
    if (prior) {
      if (prior.contentHash !== contentHash || prior.sessionKey !== sessionKey) throw new Error("RESPONSE_REPLAY_CONTENT_MISMATCH");
      const status = await prior.promise;
      return { ...status, operator_message: "IDEMPOTENT_REPLAY", duplicate_replay: { ...status.duplicate_replay, exact_response_replay_returned: true } };
    }
    if (record.acceptedResponse) throw new Error("TIM_REQUEST_ALREADY_ANSWERED");
    const promise = this.#respondNew(record, input, contentHash);
    this.responses.set(input.response_id, { contentHash, sessionKey, promise });
    record.acceptedResponse = { contentHash, responseId: input.response_id, promise };
    return promise;
  }

  async #respondNew(record, input, contentHash) {
    if (this.shuttingDown) throw new Error("SERVER_SHUTTING_DOWN");
    if (this.activeChild) throw new Error("FOREGROUND_CHILD_STILL_ACTIVE");
    const wrapperInput = { ...input, response_content_sha256: contentHash };
    let wrapperResult;
    let revisedOutcome = null;
    if (this.responseAdapter) {
      const adapted = await this.responseAdapter({ input: wrapperInput, record });
      wrapperResult = adapted?.response ?? adapted;
      revisedOutcome = adapted?.outcome ?? null;
    } else {
      const wrapper = path.join(this.repositoryRoot, "tools", "hq-dispatch", "v1", "Invoke-TsfHqDispatchTimResponse.ps1");
      const args = ["-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", wrapper];
      if (this.testOnlyQueueRoot) args.push("-TestOnlyQueueRoot", this.testOnlyQueueRoot);
      const processResult = await this.#spawnOwned(this.powershellExe, args, JSON.stringify(wrapperInput), 60_000);
      if (processResult.code !== 0) throw new Error("CANONICAL_TIM_RESPONSE_REJECTED");
      wrapperResult = JSON.parse(processResult.stdout.trim().split(/\r?\n/).at(-1));
    }
    if (wrapperResult?.response_id !== input.response_id
        || wrapperResult?.request_id !== input.tim_required_request_id
        || wrapperResult?.response_content_sha256 !== contentHash
        || wrapperResult?.worker_resumed !== false
        || wrapperResult?.original_result_unchanged !== true) {
      throw new Error("CANONICAL_TIM_RESPONSE_OUTCOME_INVALID");
    }
    record.responseOutcome = wrapperResult;
    if (input.response_type === "DENY_REQUEST") {
      if (wrapperResult.terminal_disposition !== "TIM_REQUIRED_DENIED" || wrapperResult.approval !== null || wrapperResult.revision !== null) {
        throw new Error("CANONICAL_DENIAL_OUTCOME_INVALID");
      }
      record.terminal = true;
      record.status = this.#status("TIM_REQUIRED_DENIED", record.missionId, record.revision, {
        sourcePath: wrapperResult.response_record_path,
        runId: input.run_id,
        resultId: input.result_id,
        explanation: "The canonical immutable denial record grants no authority and starts no worker.",
        assurance: "CANONICAL_TIM_DENIAL_RECORD",
        tim_request: record.timRequest,
        response: wrapperResult,
        prior_terminal: record.originalTimStatus,
        next_action: "Create a new operator-authored mission only if work should be reconsidered.",
      });
      this.#event(record, record.status);
      return record.status;
    }
    const targetRevision = Number(input.mission_revision) + 1;
    if (!wrapperResult.revision
        || Number(wrapperResult.revision.mission_revision) !== targetRevision
        || wrapperResult.revision.run_id !== `canonical-result-${record.missionId}-${targetRevision}`) {
      throw new Error("CANONICAL_REVISION_LINK_INVALID");
    }
    const revisionInput = {
      mission_id: record.missionId,
      mission_revision: targetRevision,
      parent_mission_revision: Number(input.mission_revision),
      source_result_id: input.result_id,
      tim_required_request_id: input.tim_required_request_id,
      response_id: input.response_id,
      response_record_sha256: wrapperResult.response_record_sha256,
    };
    record.revision = targetRevision;
    record.terminal = false;
    record.status = this.#status("REVISING", record.missionId, targetRevision, {
      sourcePath: wrapperResult.response_record_path,
      runId: wrapperResult.revision.run_id,
      explanation: "A new governed mission revision is being prepared; the original terminal run is not resumed.",
      assurance: "CANONICAL_RESPONSE_BOUND_REVISION",
      response: wrapperResult,
      prior_terminal: record.originalTimStatus,
    });
    this.#event(record, record.status);
    this.activeMissionId = record.missionId;
    try {
      const outcome = revisedOutcome ?? await this.#prepareAndExecute({
        missionId: record.missionId,
        missionRevision: targetRevision,
        naturalRequest: record.naturalRequest,
        revisionInput,
        approvalLedgerPath: wrapperResult.approval?.ledger_path ?? "",
      });
      this.#applyOutcome(record, outcome);
      return record.status;
    } finally {
      if (record.terminal && this.activeMissionId === record.missionId) this.activeMissionId = null;
      if (record.terminal && this.onMissionChange) this.onMissionChange(null);
    }
  }

  async #spawnOwned(executable, args, input, timeoutMs, interruptionContext = null) {
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
        if (this.onChildExit) {
          try { this.onChildExit(child.pid); } catch { /* Preserve owner evidence for Doctor. */ }
        }
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
      try {
        if (this.onChildStart) this.onChildStart(child);
      } catch {
        abortError = new Error("OWNED_CHILD_EVIDENCE_WRITE_FAILED");
        child.kill();
      }
      if (interruptionContext && this.testOnlyInterruptionBarrier && !abortError) {
        Promise.resolve(this.testOnlyInterruptionBarrier.activate(m3RealInterruptionCapabilities.get(this.testOnlyInterruptionBarrier), {
          ...interruptionContext,
          executor_child: child,
          fixture_type: this.testOnlyInterruptionBarrier.fixture_type,
          fixture_root: this.testOnlyInterruptionBarrier.fixture_root,
          test_run_identity: this.testOnlyInterruptionBarrier.test_run_identity,
          test_run_root: this.testOnlyInterruptionBarrier.test_run_root,
          timeout_ms: this.testOnlyInterruptionBarrier.timeout_ms,
        })).catch((error) => {
          abortError = error instanceof Error ? error : new Error("M3_INTERRUPTION_BARRIER_FAILED_CLOSED");
          try {
            if (this.terminateOwnedChild) this.terminateOwnedChild(child);
            else child.kill();
          } catch { child.kill(); }
        });
      }
      child.stdin.on("error", () => {});
      child.stdin.end(input, "utf8");
    });
  }

  async shutdown() {
    this.shuttingDown = true;
    const record = this.activeMissionId ? this.missions.get(this.activeMissionId) : null;
    let interruptionPending = false;
    if (record && !record.terminal) {
      record.terminal = true;
      interruptionPending = true;
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
    const childClosed = this.activeChildClosed;
    let ownedProcessCleanup = null;
    // The live ChildProcess handle is only an operational convenience.  Always
    // enter the registered cleanup authority, including after the root close
    // callback has cleared activeChild, so independently registered descendants
    // remain exact cleanup obligations.
    if (this.terminateOwnedChild) ownedProcessCleanup = await this.terminateOwnedChild(child);
    else if (child && !child.killed) child.kill();
    if (childClosed) {
      await Promise.race([
        childClosed,
        new Promise((resolve) => setTimeout(resolve, 15_000)),
      ]);
    }
    if (this.activeChild) throw new Error("OWNED_CHILD_CLOSE_CONFIRMATION_TIMEOUT");
    if (this.testOnlyInterruptionBarrier) {
      await this.testOnlyInterruptionBarrier.cleanup(m3RealInterruptionCapabilities.get(this.testOnlyInterruptionBarrier));
    }
    if (interruptionPending && this.onInterrupted) {
      try { record.interruption = await this.onInterrupted(record); }
      catch (error) { record.interruption_error = errorCode(error); }
    }
    this.previews.clear();
    if (!this.activeChild && this.onMissionChange) this.onMissionChange(null);
    return {
      child_exited: !this.activeChild,
      interrupted_mission_id: record?.missionId ?? null,
      interruption: record?.interruption ?? null,
      owned_process_cleanup: ownedProcessCleanup,
      active_mission_snapshot: record ? {
        mission_id: record.missionId,
        mission_revision: record.revision,
        run_id: record.preparation?.run_id ?? null,
        result_id: record.preparation?.run_id ?? null,
      } : null,
    };
  }

  async retryInterrupted({ item, interruption = null, sessionGeneration = "" }) {
    if (this.shuttingDown) throw new Error("SERVER_SHUTTING_DOWN");
    if (!item || !["INTERRUPTED_PROCESS_GONE", "DISPATCHING_WITHOUT_OWNER"].includes(item.classification)) {
      throw new Error("NEW_RUN_RECOVERY_SOURCE_NOT_INTERRUPTED");
    }
    if (this.activeMissionId) throw new Error("ONE_ACTIVE_MISSION_LIMIT");
    const recoveryEvidencePath = interruption?.stop_record_path ?? item.interruption_evidence?.path;
    if (!recoveryEvidencePath || !existsSync(recoveryEvidencePath)) throw new Error("NEW_RUN_RECOVERY_EVIDENCE_MISSING");
    const recoveryEvidenceDirectory = path.dirname(recoveryEvidencePath);
    const recoveryKey = jsonHash({ source: item.evidence_hash, sessionGeneration });
    const prior = this.recoveries.get(recoveryKey);
    if (prior) return prior;

    const sourceMissionPath = (item.canonical_paths?.mission ?? [])[0];
    if (!sourceMissionPath || !existsSync(sourceMissionPath)) throw new Error("NEW_RUN_SOURCE_MISSION_MISSING");
    const sourceMission = parseJsonFile(sourceMissionPath);
    const suffix = randomBytes(8).toString("hex");
    const prefix = String(item.mission_id).replace(/[^A-Za-z0-9._:-]/g, "-").slice(0, 118);
    const missionId = `${prefix}-retry-${suffix}`;
    const runId = `canonical-result-${missionId}-1`;
    const record = {
      missionId,
      requestHash: hash(String(sourceMission.original_request ?? "")),
      previewId: null,
      naturalRequest: String(sourceMission.original_request ?? ""),
      revision: 1,
      sessionKey: sessionGeneration,
      replayKey: recoveryKey,
      events: [],
      terminal: false,
      recoveryParent: { mission_id: item.mission_id, mission_revision: item.mission_revision, run_id: item.run_id, evidence_hash: item.evidence_hash },
      status: this.#status("PREPARING", missionId, 1, {
        runId,
        explanation: "A new run is being prepared through canonical routing and queue controls; the interrupted source run remains immutable.",
        assurance: "CANONICAL_NEW_RUN_RECOVERY_PENDING",
      }),
    };
    this.activeMissionId = missionId;
    this.missions.set(missionId, record);
    this.#event(record, record.status);
    const promise = (async () => {
      try {
        const outcome = this.executionAdapter
          ? await this.executionAdapter({ missionId, missionRevision: 1, naturalRequest: record.naturalRequest, recoveryParent: record.recoveryParent })
          : await this.#prepareAndExecute({
            missionId,
            missionRevision: 1,
            naturalRequest: record.naturalRequest,
            revisionInput: {
              mission_id: missionId,
              mission_revision: 1,
              natural_request: record.naturalRequest,
              recovery_parent_mission_id: item.mission_id,
              recovery_parent_mission_revision: item.mission_revision,
              recovery_parent_run_id: item.run_id,
              recovery_source_evidence_sha256: item.evidence_hash,
              recovery_evidence_directory: recoveryEvidenceDirectory,
            },
          });
        this.#applyOutcome(record, outcome);
        record.status = { ...record.status, recovery_parent: record.recoveryParent, new_run_identity: true, old_thread_or_turn_resumed: false };
        return { ...record.status, operator_message: "NEW_RUN_REQUIRED" };
      } finally {
        if (record.terminal && this.activeMissionId === missionId) this.activeMissionId = null;
        if (record.terminal && this.onMissionChange) this.onMissionChange(null);
      }
    })();
    this.recoveries.set(recoveryKey, promise);
    return promise;
  }

  loadReconciledTimRequired(item, sessionKey) {
    if (!item || item.classification !== "TIM_REQUIRED_PENDING_RESPONSE") throw new Error("RECONCILED_TIM_REQUIRED_SOURCE_INVALID");
    const existing = this.missions.get(item.mission_id);
    if (existing) {
      if (existing.sessionKey !== sessionKey || existing.reconciliationEvidenceHash !== item.evidence_hash) throw new Error("CROSS_SESSION_TIM_RESPONSE");
      return existing.status;
    }
    const first = (role) => {
      const values = item.canonical_paths?.[role] ?? [];
      return Array.isArray(values) ? values[0] ?? "" : values;
    };
    const lifecyclePath = first("lifecycle");
    const missionPath = first("mission");
    const runtimeQueuePath = first("runtime_queue_document");
    const queueRecordPath = first("queue_documents") || runtimeQueuePath;
    if (!lifecyclePath || !missionPath || !queueRecordPath || !existsSync(lifecyclePath) || !existsSync(missionPath) || !existsSync(queueRecordPath)) {
      throw new Error("RECONCILED_TIM_REQUIRED_CANONICAL_PATH_MISSING");
    }
    const lifecycle = parseJsonFile(lifecyclePath);
    const mission = parseJsonFile(missionPath);
    const queueResultPath = first("queue_result");
    const adapterPath = first("adapter");
    const verifierPath = first("verifier");
    const resultPath = first("result");
    const queueResult = queueResultPath && existsSync(queueResultPath) ? parseJsonFile(queueResultPath) : { final_decision: "TIM_REQUIRED_RECONCILED", final_queue_state: item.last_known_queue_state };
    const adapter = adapterPath && existsSync(adapterPath) ? parseJsonFile(adapterPath) : null;
    const verifier = verifierPath && existsSync(verifierPath) ? parseJsonFile(verifierPath) : null;
    const durableResult = resultPath && existsSync(resultPath) ? parseJsonFile(resultPath) : null;
    const preparation = {
      mission_id: item.mission_id,
      mission_revision: item.mission_revision,
      run_id: item.run_id,
      mission_path: missionPath,
      queue_record_path: queueRecordPath,
      queue_result_path: queueResultPath,
      lifecycle_result_path: lifecyclePath,
      adapter_result_path: adapterPath,
      verifier_result_path: verifierPath,
      preservation_packet_path: lifecycle.preservation_packet_file ?? "",
      route: { worker_role: mission.worker_role ?? null, resolved_model: mission.resolved_model ?? null, effort: mission.reasoning_effort ?? null },
      access: { permission_mode: mission.permission_mode ?? null, network_policy: mission.network_policy ?? null, control_plane_service_network_policy: mission.control_plane_service_network_policy ?? null, worker_tool_network_policy: mission.worker_tool_network_policy ?? null, allowed_reads: mission.allowed_reads ?? [], allowed_writes: mission.allowed_writes ?? [] },
    };
    const record = {
      missionId: item.mission_id,
      requestHash: hash(String(mission.original_request ?? "")),
      previewId: null,
      naturalRequest: String(mission.original_request ?? ""),
      revision: item.mission_revision,
      sessionKey,
      replayKey: item.evidence_hash,
      reconciliationEvidenceHash: item.evidence_hash,
      events: [],
      terminal: false,
      status: this.#status("RECONCILING", item.mission_id, item.mission_revision, { sourcePath: lifecyclePath, runId: item.run_id, explanation: "Canonical TIM_REQUIRED evidence is being projected without resuming the old run.", assurance: "CANONICAL_RESTART_RECONCILIATION" }),
    };
    this.missions.set(item.mission_id, record);
    this.#event(record, record.status);
    this.#applyOutcome(record, { preparation, processResult: { code: 1, child_exited: true, stdout: "", stderr: "TIM_REQUIRED" }, queueResult, lifecycle, adapter, verifier, workerResult: null, durableResult });
    return { ...record.status, restart_reconciled: true, automatic_rerun_performed: false, old_thread_or_turn_resumed: false };
  }

  async reconcileQueueFromCanonicalReceipt(item) {
    if (!item || item.classification !== "ADMISSION_WITH_QUEUE_MISMATCH") throw new Error("QUEUE_RECONCILIATION_SOURCE_INVALID");
    const first = (role) => {
      const values = item.canonical_paths?.[role] ?? [];
      return Array.isArray(values) ? values[0] ?? "" : values;
    };
    const queuePath = first("queue_documents");
    const receiptPath = first("admission");
    const transactionPath = first("transaction");
    if (!queuePath || !receiptPath || !transactionPath || !existsSync(queuePath) || !existsSync(receiptPath) || !existsSync(transactionPath)) throw new Error("QUEUE_RECONCILIATION_CANONICAL_EVIDENCE_MISSING");
    const wrapper = path.join(this.repositoryRoot, "tools", "hq-dispatch", "v1", "Invoke-TsfHqDispatchQueueReconcileV1.ps1");
    const args = ["-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", wrapper];
    if (this.testOnlyQueueRoot) args.push("-TestOnlyQueueRoot", this.testOnlyQueueRoot, "-UnsupportedDevelopmentMode");
    const input = {
      mission_id: item.mission_id,
      mission_revision: item.mission_revision,
      run_id: item.run_id,
      result_id: item.result_id,
      queue_record_path: queuePath,
      queue_record_sha256: hash(readFileSync(queuePath)),
      receipt_path: receiptPath,
      receipt_sha256: hash(readFileSync(receiptPath)),
      transaction_path: transactionPath,
      transaction_sha256: hash(readFileSync(transactionPath)),
      source_evidence_sha256: item.evidence_hash,
    };
    const result = await this.#spawnOwned(this.powershellExe, args, JSON.stringify(input), 60_000);
    if (result.code !== 0) throw new Error("CANONICAL_QUEUE_RECONCILIATION_REJECTED");
    const parsed = JSON.parse(result.stdout.trim().split(/\r?\n/).at(-1));
    if (parsed.schema_version !== "tsf_hq_dispatch_queue_reconciliation_result_v1" || parsed.mission_id !== item.mission_id || Number(parsed.mission_revision) !== item.mission_revision || parsed.run_id !== item.run_id || parsed.source_evidence_sha256 !== item.evidence_hash || parsed.canonical_history_preserved !== true || parsed.approval_inferred !== false) throw new Error("CANONICAL_QUEUE_RECONCILIATION_RESULT_INVALID");
    return parsed;
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
      result_id: status.result_id,
      assurance: status.assurance,
      explanation: status.explanation,
    });
  }

  #assertOutcomeIdentity(record, outcome) {
    const { preparation, queueResult, lifecycle, adapter, verifier, workerResult, durableResult, mission } = outcome;
    if (!preparation || preparation.mission_id !== record.missionId || Number(preparation.mission_revision) !== record.revision) {
      throw new Error("CANONICAL_MISSION_IDENTITY_MISMATCH");
    }
    const expectedResultId = preparation.run_id;
    if (expectedResultId !== `canonical-result-${record.missionId}-${record.revision}`) {
      throw new Error("CANONICAL_RUN_IDENTITY_MISMATCH");
    }
    const identities = [
      ["queue admission", queueResult?.admission_receipt?.result_id],
      ["lifecycle run", lifecycle?.run_id],
      ["adapter run", adapter?.run_id],
      ["adapter result", adapter?.result_id],
      ["worker run", workerResult?.exact_response_evidence?.run_id],
      ["worker result", workerResult?.exact_response_evidence?.result_id],
      ["verifier run", verifier?.exact_response_evidence?.run_id],
      ["verifier result", verifier?.exact_response_evidence?.result_id],
      ["durable result", durableResult?.result_id],
    ];
    for (const [source, identity] of identities) {
      if (identity !== undefined && identity !== null && identity !== "" && identity !== expectedResultId) {
        throw new Error(`CANONICAL_RESULT_IDENTITY_MISMATCH:${source}`);
      }
    }
    for (const source of [adapter, workerResult?.exact_response_evidence, verifier?.exact_response_evidence, durableResult]) {
      if (!source) continue;
      if (source.mission_id !== undefined && source.mission_id !== record.missionId) throw new Error("CANONICAL_MISSION_IDENTITY_MISMATCH");
      if (source.mission_revision !== undefined && Number(source.mission_revision) !== record.revision) throw new Error("CANONICAL_REVISION_IDENTITY_MISMATCH");
    }
    for (const claims of [adapter?.observation_claims, workerResult?.observation_claims, durableResult?.observation_claims]) {
      if (!claims) continue;
      for (const claim of Object.values(claims)) {
        if (claim?.run_id !== expectedResultId) throw new Error("CROSS_RUN_OBSERVATION_CLAIM_REJECTED");
      }
    }
    if (mission) {
      assertContractContinuation(record.reviewedResponseContract ?? reviewedContractForm(record.responseContract), mission.exact_response_contract ?? null, record.missionId, record.revision);
      if (preparation.exact_response_contract !== undefined && jsonHash(preparation.exact_response_contract) !== jsonHash(mission.exact_response_contract ?? null)) {
        throw new Error("EXACT_RESPONSE_CONTRACT_PREPARATION_MISMATCH");
      }
      const semanticHash = mission.exact_response_contract?.semantic_contract_sha256 ?? null;
      for (const evidence of [workerResult?.exact_response_evidence, verifier?.exact_response_evidence]) {
        if (evidence && evidence.semantic_contract_sha256 !== semanticHash) throw new Error("EXACT_RESPONSE_CONTRACT_RESULT_MISMATCH");
      }
    }
  }

  #status(state, missionId, revision, fields = {}) {
    const record = this.missions.get(missionId);
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
      requested_response: record ? { natural_request: record.naturalRequest, request_sha256: record.requestHash } : null,
      response_contract: fields.response_contract ?? record?.responseContract ?? null,
      tim_request: fields.tim_request ?? null,
      response: fields.response ?? record?.responseOutcome ?? null,
      prior_terminal: fields.prior_terminal ?? record?.originalTimStatus ?? null,
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
      process_id: adapter?.child_process_id ?? null,
      model: adapter?.observed_model ?? null,
      effort: adapter?.effective_effort ?? adapter?.canonical_resolved_effort ?? null,
      child_exited: adapter?.child_exited ?? null,
      no_orphan_process: adapter?.no_orphan_process ?? null,
      changed_paths: durableResult?.files_changed ?? workerResult?.files_touched ?? [],
      created_paths: workerResult?.files_created ?? [],
      tests: durableResult?.tests ?? workerResult?.tests ?? [],
      exact_response: workerResult?.exact_response_evidence ?? null,
      observation_claims: durableResult?.observation_claims ?? workerResult?.observation_claims ?? adapter?.observation_claims ?? null,
    };
  }

  #verifierProjection(verifier, lifecycle, verifierPath) {
    return { identity: "canonical-kernel-postrun", verdict: verifier?.verdict ?? lifecycle?.verifier_verdict ?? "NOT_OBSERVED", verified: verifier?.verified ?? false, exact_response: verifier?.exact_response_evidence ?? null, result_path: verifierPath ?? null, result_sha256: this.#safeFileHash(verifierPath) };
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
      result_id: durableResult?.result_id ?? queueResult?.admission_receipt?.result_id ?? null,
      mission_sha256: preparation?.mission_sha256 ?? null,
      queue_document_sha256: preparation?.queue_document_sha256 ?? null,
      durable_result_path: queueResult?.durable_result_path ?? null,
      durable_result_sha256: this.#safeFileHash(queueResult?.durable_result_path),
      tests: durableResult?.tests ?? [],
      observation_claims: durableResult?.observation_claims ?? null,
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
