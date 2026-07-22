import { createHash } from "node:crypto";

export const EXACT_RESPONSE_CONTRACT_MODE = "EXACT_LITERAL_V1";
export const NO_EXACT_RESPONSE_CONTRACT_MODE = "NOT_APPLICABLE_NO_EXACT_RESPONSE_CONTRACT";
export const NONAUTHORITATIVE_WORKER_REVISION_DISPOSITION = "NOT_PRESENT_IN_NONAUTHORITATIVE_WORKER_PAYLOAD";
export const LEGACY_M2A_LITERAL = "TSF_HQ_DISPATCH_READ_ONLY_GREEN";

function sha256(value) {
  return createHash("sha256").update(String(value), "utf8").digest("hex");
}

function stableValue(value) {
  if (Array.isArray(value)) return value.map(stableValue);
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.keys(value).sort().map((key) => [key, stableValue(value[key])]));
  }
  return value;
}

function stableJson(value) {
  return JSON.stringify(stableValue(value));
}

function fail(code, details = {}) {
  throw new Error(`${code}:${JSON.stringify(details)}`);
}

function requireInvariant(checks, condition, code, details = {}) {
  if (!condition) fail(code, details);
  checks.push(code);
}

function isAbsent(value) {
  return value === null || value === undefined;
}

function requireIdentity(checks, label, evidence, expected) {
  requireInvariant(checks, evidence?.mission_id === expected.mission_id, `${label}_MISSION_ID_MISMATCH`, { expected: expected.mission_id, observed: evidence?.mission_id ?? null });
  requireInvariant(checks, Number(evidence?.mission_revision) === Number(expected.mission_revision), `${label}_MISSION_REVISION_MISMATCH`, { expected: expected.mission_revision, observed: evidence?.mission_revision ?? null });
  requireInvariant(checks, evidence?.run_id === expected.run_id, `${label}_RUN_ID_MISMATCH`, { expected: expected.run_id, observed: evidence?.run_id ?? null });
  requireInvariant(checks, evidence?.result_id === expected.result_id, `${label}_RESULT_ID_MISMATCH`, { expected: expected.result_id, observed: evidence?.result_id ?? null });
}

function requireMissionRevisionRunIdentity(checks, label, evidence, expected) {
  requireInvariant(checks, evidence?.mission_id === expected.mission_id, `${label}_MISSION_ID_MISMATCH`, { expected: expected.mission_id, observed: evidence?.mission_id ?? null });
  requireInvariant(checks, Number(evidence?.mission_revision) === Number(expected.mission_revision), `${label}_MISSION_REVISION_MISMATCH`, { expected: expected.mission_revision, observed: evidence?.mission_revision ?? null });
  requireInvariant(checks, evidence?.run_id === expected.run_id, `${label}_RUN_ID_MISMATCH`, { expected: expected.run_id, observed: evidence?.run_id ?? null });
}

function requireCanonicalResultIdentity(checks, canonicalResult, expected) {
  requireInvariant(checks, canonicalResult?.mission_id === expected.mission_id, "CANONICAL_RESULT_MISSION_ID_MISMATCH", { expected: expected.mission_id, observed: canonicalResult?.mission_id ?? null });
  requireInvariant(checks, Number(canonicalResult?.mission_revision) === Number(expected.mission_revision), "CANONICAL_RESULT_MISSION_REVISION_MISMATCH", { expected: expected.mission_revision, observed: canonicalResult?.mission_revision ?? null });
  requireInvariant(checks, canonicalResult?.result_id === expected.result_id && canonicalResult.result_id === expected.run_id, "CANONICAL_RESULT_RESULT_ID_MISMATCH", { expected_result_id: expected.result_id, expected_run_id: expected.run_id, observed: canonicalResult?.result_id ?? null });
  if (canonicalResult.run_id !== undefined && canonicalResult.run_id !== null) {
    requireInvariant(checks, canonicalResult.run_id === expected.run_id, "CANONICAL_RESULT_OPTIONAL_RUN_ID_MISMATCH", { expected: expected.run_id, observed: canonicalResult.run_id });
  }
  return canonicalResult.run_id === undefined || canonicalResult.run_id === null
    ? "RUN_ID_REPRESENTED_BY_CANONICAL_RESULT_ID"
    : "OPTIONAL_CANONICAL_RESULT_RUN_ID_MATCHED";
}

function artifactEntry(entries, logicalType, label) {
  const matches = (Array.isArray(entries) ? entries : []).filter((entry) => entry?.logical_type === logicalType);
  if (matches.length !== 1) fail(`${label}_${logicalType.toUpperCase()}_ARTIFACT_CARDINALITY_INVALID`, { observed: matches.length });
  return matches[0];
}

function requireWorkerArtifactIdentityBinding(checks, {
  workerResult,
  workerResultArtifact,
  lifecycle,
  adapter,
  adapterArtifact,
  canonicalAdapterArtifact,
  producerRegistry,
  producerRegistryArtifact,
  preservationManifest,
  canonicalResult,
  expected,
}) {
  requireInvariant(checks, workerResult?.schema_version === 1, "WORKER_RESULT_SCHEMA_VERSION_UNSUPPORTED", { observed: workerResult?.schema_version ?? null });
  requireInvariant(checks, workerResult?.mission_id === expected.mission_id, "WORKER_RESULT_MISSION_ID_MISMATCH");
  requireInvariant(checks, /^[a-f0-9]{64}$/.test(String(workerResultArtifact?.sha256 ?? "")) && typeof workerResultArtifact?.path === "string" && workerResultArtifact.path.length > 0, "WORKER_RESULT_ARTIFACT_EVIDENCE_INVALID");
  requireInvariant(checks, /^[a-f0-9]{64}$/.test(String(adapterArtifact?.sha256 ?? "")) && typeof adapterArtifact?.path === "string" && adapterArtifact.path.length > 0, "ADAPTER_ARTIFACT_EVIDENCE_INVALID");
  requireInvariant(checks, /^[a-f0-9]{64}$/.test(String(canonicalAdapterArtifact?.sha256 ?? "")) && typeof canonicalAdapterArtifact?.path === "string" && canonicalAdapterArtifact.path.length > 0, "CANONICAL_ADAPTER_ARTIFACT_EVIDENCE_INVALID");

  requireIdentity(checks, "LIFECYCLE", lifecycle, expected);
  requireIdentity(checks, "ADAPTER", adapter, expected);
  const canonicalResultRunDisposition = requireCanonicalResultIdentity(checks, canonicalResult, expected);
  requireMissionRevisionRunIdentity(checks, "PRODUCER_REGISTRY_BINDING", producerRegistry?.binding, expected);
  requireMissionRevisionRunIdentity(checks, "PRESERVATION_MANIFEST", preservationManifest, expected);

  const queueHash = String(lifecycle?.queue_document_sha256 ?? "");
  requireInvariant(checks, /^[a-f0-9]{64}$/.test(queueHash), "CANONICAL_QUEUE_HASH_INVALID");
  requireInvariant(checks, adapter?.queue_document_sha256 === queueHash, "ADAPTER_QUEUE_HASH_MISMATCH");
  requireInvariant(checks, producerRegistry?.binding?.queue_document_sha256 === queueHash, "PRODUCER_REGISTRY_QUEUE_HASH_MISMATCH");

  requireInvariant(checks, lifecycle?.worker_result_path === workerResultArtifact.path, "LIFECYCLE_WORKER_RESULT_PATH_MISMATCH");
  requireInvariant(checks, lifecycle?.producer_registry_path === producerRegistryArtifact?.path, "LIFECYCLE_PRODUCER_REGISTRY_PATH_MISMATCH");
  requireInvariant(checks, workerResult?.adapter_result_path === adapterArtifact.path, "WORKER_ADAPTER_PATH_MISMATCH", { expected: workerResult?.adapter_result_path ?? null, observed: adapterArtifact.path });
  requireInvariant(checks, workerResult?.adapter_result_sha256 === adapterArtifact.sha256, "WORKER_ADAPTER_HASH_MISMATCH", { expected: workerResult?.adapter_result_sha256 ?? null, observed: adapterArtifact.sha256 });
  requireInvariant(checks, canonicalAdapterArtifact.sha256 === adapterArtifact.sha256, "CANONICAL_ADAPTER_COPY_HASH_MISMATCH", { worker_bound_path: adapterArtifact.path, canonical_copy_path: canonicalAdapterArtifact.path });

  const registryWorker = artifactEntry(producerRegistry?.artifacts, "worker_result", "PRODUCER_REGISTRY");
  requireInvariant(checks, registryWorker.sha256 === workerResultArtifact.sha256, "PRODUCER_REGISTRY_WORKER_HASH_MISMATCH");
  const manifestWorker = artifactEntry(preservationManifest?.artifacts, "worker_result", "PRESERVATION_MANIFEST");
  requireInvariant(checks, manifestWorker.sha256 === workerResultArtifact.sha256, "PRESERVATION_MANIFEST_WORKER_HASH_MISMATCH");
  const manifestAdapter = artifactEntry(preservationManifest?.artifacts, "adapter_result", "PRESERVATION_MANIFEST");
  requireInvariant(checks, manifestAdapter.sha256 === adapterArtifact.sha256, "PRESERVATION_MANIFEST_ADAPTER_HASH_MISMATCH");

  for (const [field, code] of [["mission_revision", "WORKER_ROOT_MISSION_REVISION_MISMATCH"], ["run_id", "WORKER_ROOT_RUN_ID_MISMATCH"], ["result_id", "WORKER_ROOT_RESULT_ID_MISMATCH"]]) {
    if (workerResult[field] === undefined || workerResult[field] === null) continue;
    const observed = field === "mission_revision" ? Number(workerResult[field]) : workerResult[field];
    const wanted = field === "mission_revision" ? Number(expected[field]) : expected[field];
    requireInvariant(checks, observed === wanted, code, { expected: wanted, observed });
  }
  for (const [claimName, claim] of Object.entries(workerResult?.observation_claims ?? {})) {
    requireInvariant(checks, claim?.run_id === expected.run_id, "WORKER_OBSERVATION_CLAIM_RUN_ID_MISMATCH", { claim: claimName, expected: expected.run_id, observed: claim?.run_id ?? null });
  }

  return {
    workerPayloadRevisionDisposition: workerResult.mission_revision === undefined || workerResult.mission_revision === null
      ? NONAUTHORITATIVE_WORKER_REVISION_DISPOSITION
      : "OPTIONAL_WORKER_ROOT_REVISION_MATCHED",
    canonicalResultRunDisposition,
  };
}

function requireAdmission(checks, admission, expected) {
  requireInvariant(checks, ["ADMITTED", "ADMITTED_WITH_CAVEATS"].includes(admission?.status), "RECOVERY_ADMISSION_STATUS_INVALID", { observed: admission?.status ?? null });
  requireInvariant(checks, admission?.mission_id === expected.mission_id, "RECOVERY_ADMISSION_MISSION_ID_MISMATCH");
  requireInvariant(checks, Number(admission?.mission_revision) === Number(expected.mission_revision), "RECOVERY_ADMISSION_MISSION_REVISION_MISMATCH");
  requireInvariant(checks, admission?.result_id === expected.result_id, "RECOVERY_ADMISSION_RESULT_ID_MISMATCH");
}

function requireNormalVerifierContract(checks, workerResult, verifier) {
  const workerTests = Array.isArray(workerResult?.tests) ? workerResult.tests : [workerResult?.tests].filter(Boolean);
  requireInvariant(checks, workerResult?.role_output_contract_satisfied === true, "GENERAL_WORKER_ROLE_CONTRACT_NOT_SATISFIED");
  requireInvariant(checks, workerTests.some((test) => test?.test_id === "hq-dispatch-read-only-general-result" && test?.status === "PASS"), "GENERAL_WORKER_RESULT_TEST_NOT_PASS");
  requireInvariant(checks, verifier?.verdict === "GREEN" && verifier?.verified === true, "GENERAL_VERIFIER_NOT_GREEN");
  requireInvariant(checks, Array.isArray(verifier?.checks) && verifier.checks.length > 0 && verifier.checks.every((item) => item?.status === "PASS" && item?.passed === true), "GENERAL_VERIFIER_CHECKS_NOT_PASS");
}

export function verifyRecoveryResultContractEvidence({
  mission,
  queueDocument,
  workerResult,
  verifier,
  admission,
  recoveryRun,
  lifecycle,
  adapter,
  canonicalResult,
  producerRegistry,
  preservationManifest,
  workerResultArtifact,
  adapterArtifact,
  canonicalAdapterArtifact,
  producerRegistryArtifact,
  interruptedSourceContract = null,
  legacyM2aLiteral = LEGACY_M2A_LITERAL,
}) {
  const checks = [];
  requireInvariant(checks, mission && queueDocument && workerResult && verifier && admission && recoveryRun, "RECOVERY_RESULT_CONTRACT_INPUT_INCOMPLETE");

  const expected = {
    mission_id: recoveryRun.mission_id,
    mission_revision: recoveryRun.mission_revision,
    run_id: recoveryRun.run_id,
    result_id: recoveryRun.result_id,
  };
  requireInvariant(checks, mission.mission_id === expected.mission_id, "RECOVERY_MISSION_ID_MISMATCH");
  requireInvariant(checks, Number(mission.mission_revision) === Number(expected.mission_revision), "RECOVERY_MISSION_REVISION_MISMATCH");
  requireInvariant(checks, queueDocument?.durable_mission?.mission_id === expected.mission_id, "RECOVERY_QUEUE_MISSION_ID_MISMATCH");
  requireInvariant(checks, Number(queueDocument?.durable_mission?.mission_revision) === Number(expected.mission_revision), "RECOVERY_QUEUE_MISSION_REVISION_MISMATCH");
  requireInvariant(checks, recoveryRun.state === admission.status, "RECOVERY_RUN_ADMISSION_STATUS_MISMATCH", { run_state: recoveryRun.state, admission_status: admission.status });
  const identityDispositions = requireWorkerArtifactIdentityBinding(checks, {
    workerResult,
    workerResultArtifact,
    lifecycle,
    adapter,
    adapterArtifact,
    canonicalAdapterArtifact,
    producerRegistry,
    producerRegistryArtifact,
    preservationManifest,
    canonicalResult,
    expected,
  });

  const missionContract = mission.exact_response_contract ?? null;
  const upstreamContracts = [
    ["DURABLE_MISSION", queueDocument?.durable_mission?.exact_response_contract],
    ["MISSION_PACKET", queueDocument?.mission_packet?.exact_response_contract],
    ["WORKER_INSTRUCTION", queueDocument?.worker_instruction_packet?.exact_response_contract],
    ["RECOVERY_RUN", recoveryRun?.response_contract],
  ];
  const exactMode = missionContract?.validation_mode === EXACT_RESPONSE_CONTRACT_MODE;
  requireInvariant(checks, isAbsent(missionContract) || exactMode, "RECOVERY_MISSION_EXACT_RESPONSE_MODE_UNSUPPORTED", { validation_mode: missionContract?.validation_mode ?? null });

  if (!exactMode) {
    requireInvariant(checks, isAbsent(missionContract), "GENERAL_MISSION_CONTRACT_MUST_BE_ABSENT");
    for (const [label, contract] of upstreamContracts) {
      requireInvariant(checks, isAbsent(contract), `GENERAL_${label}_CONTRACT_MUST_BE_ABSENT`);
    }
    requireInvariant(checks, isAbsent(workerResult.exact_response_evidence), "GENERAL_WORKER_FABRICATED_EXACT_RESPONSE_EVIDENCE");
    requireInvariant(checks, isAbsent(verifier.exact_response_evidence), "GENERAL_VERIFIER_FABRICATED_EXACT_RESPONSE_EVIDENCE");
    requireInvariant(checks, isAbsent(recoveryRun?.worker?.exact_response), "GENERAL_RUN_WORKER_FABRICATED_EXACT_RESPONSE_EVIDENCE");
    requireInvariant(checks, isAbsent(recoveryRun?.verifier?.exact_response), "GENERAL_RUN_VERIFIER_FABRICATED_EXACT_RESPONSE_EVIDENCE");
    const exactTask = String(queueDocument?.worker_instruction_packet?.exact_task ?? "");
    requireInvariant(checks, !/\breturn\s+exactly\s+[A-Z][A-Z0-9_]*\b/i.test(exactTask), "GENERAL_WORKER_INSTRUCTION_CONTAINS_EXACT_LITERAL_REQUIREMENT", { exact_task: exactTask });
    requireInvariant(checks, !stableJson({ mission, queueDocument, workerResult, verifier }).includes(legacyM2aLiteral), "GENERAL_RESULT_CONTAINS_M2A_FALLBACK_LITERAL");
    requireInvariant(checks, workerResult.mission_id === expected.mission_id, "GENERAL_WORKER_MISSION_ID_MISMATCH");
    requireIdentity(checks, "GENERAL_VERIFIER", verifier, expected);
    requireNormalVerifierContract(checks, workerResult, verifier);
    requireAdmission(checks, admission, expected);
    requireInvariant(checks, isAbsent(interruptedSourceContract) || stableJson(interruptedSourceContract) !== stableJson(verifier.exact_response_evidence), "GENERAL_RECOVERY_REUSED_INTERRUPTED_EXACT_RESPONSE_EVIDENCE");
    return {
      validation_mode: NO_EXACT_RESPONSE_CONTRACT_MODE,
      exact_response_evidence_disposition: NO_EXACT_RESPONSE_CONTRACT_MODE,
      worker_payload_revision_disposition: identityDispositions.workerPayloadRevisionDisposition,
      canonical_result_run_disposition: identityDispositions.canonicalResultRunDisposition,
      assertion_count: checks.length,
      checks,
    };
  }

  requireInvariant(checks, typeof missionContract.expected_literal === "string" && missionContract.expected_literal.length > 0, "EXACT_CONTRACT_EXPECTED_LITERAL_MISSING");
  requireInvariant(checks, /^[a-f0-9]{64}$/.test(String(missionContract.expected_literal_sha256 ?? "")), "EXACT_CONTRACT_EXPECTED_HASH_MISSING");
  requireInvariant(checks, sha256(missionContract.expected_literal) === missionContract.expected_literal_sha256, "EXACT_CONTRACT_EXPECTED_HASH_RECOMPUTE_MISMATCH");
  requireInvariant(checks, missionContract.mission_binding?.mission_id === expected.mission_id, "EXACT_CONTRACT_MISSION_BINDING_MISMATCH");
  requireInvariant(checks, Number(missionContract.mission_binding?.mission_revision) === Number(expected.mission_revision), "EXACT_CONTRACT_REVISION_BINDING_MISMATCH");
  for (const [label, contract] of upstreamContracts) {
    requireInvariant(checks, !isAbsent(contract), `EXACT_${label}_CONTRACT_MISSING`);
    requireInvariant(checks, stableJson(contract) === stableJson(missionContract), `EXACT_${label}_CONTRACT_MISMATCH`);
  }
  requireInvariant(checks, !isAbsent(workerResult.exact_response_evidence), "EXACT_WORKER_EVIDENCE_MISSING");
  requireInvariant(checks, !isAbsent(verifier.exact_response_evidence), "EXACT_VERIFIER_EVIDENCE_MISSING");
  requireInvariant(checks, !isAbsent(recoveryRun?.worker?.exact_response), "EXACT_RUN_WORKER_EVIDENCE_MISSING");
  requireInvariant(checks, !isAbsent(recoveryRun?.verifier?.exact_response), "EXACT_RUN_VERIFIER_EVIDENCE_MISSING");

  const workerEvidence = workerResult.exact_response_evidence;
  const verifierEvidence = verifier.exact_response_evidence;
  requireIdentity(checks, "EXACT_WORKER", workerEvidence, expected);
  requireIdentity(checks, "EXACT_VERIFIER", verifierEvidence, expected);
  for (const [label, evidence] of [["WORKER", workerEvidence], ["VERIFIER", verifierEvidence]]) {
    requireInvariant(checks, evidence.validation_mode === EXACT_RESPONSE_CONTRACT_MODE, `EXACT_${label}_VALIDATION_MODE_MISMATCH`);
    requireInvariant(checks, evidence.expected_literal === missionContract.expected_literal, `EXACT_${label}_EXPECTED_LITERAL_MISMATCH`);
    requireInvariant(checks, evidence.expected_response_sha256 === missionContract.expected_literal_sha256, `EXACT_${label}_EXPECTED_HASH_MISMATCH`);
    requireInvariant(checks, evidence.semantic_contract_sha256 === missionContract.semantic_contract_sha256, `EXACT_${label}_SEMANTIC_CONTRACT_MISMATCH`);
    requireInvariant(checks, sha256(evidence.observed_literal) === evidence.observed_response_sha256, `EXACT_${label}_OBSERVED_HASH_RECOMPUTE_MISMATCH`);
    requireInvariant(checks, evidence.observed_literal === missionContract.expected_literal, `EXACT_${label}_SUBSTITUTED_LITERAL`);
    requireInvariant(checks, evidence.observed_response_sha256 === missionContract.expected_literal_sha256, `EXACT_${label}_SEMANTIC_HASH_MISMATCH`);
    requireInvariant(checks, evidence.exact_match === true, `EXACT_${label}_MATCH_NOT_TRUE`);
  }
  requireInvariant(checks, workerEvidence.transport_success === true && workerEvidence.semantic_success === true, "EXACT_WORKER_SEMANTIC_SUCCESS_NOT_TRUE");
  requireInvariant(checks, verifierEvidence.independently_recomputed === true && verifier.verdict === "GREEN" && verifier.verified === true, "EXACT_VERIFIER_NOT_INDEPENDENT_GREEN");
  requireInvariant(checks, stableJson(recoveryRun.worker.exact_response) === stableJson(workerEvidence), "EXACT_RUN_WORKER_PROJECTION_MISMATCH");
  requireInvariant(checks, stableJson(recoveryRun.verifier.exact_response) === stableJson(verifierEvidence), "EXACT_RUN_VERIFIER_PROJECTION_MISMATCH");
  requireAdmission(checks, admission, expected);
  if (!isAbsent(interruptedSourceContract) && stableJson(interruptedSourceContract) !== stableJson(missionContract)) {
    requireInvariant(checks, workerEvidence.semantic_contract_sha256 !== interruptedSourceContract.semantic_contract_sha256, "EXACT_RECOVERY_REUSED_INTERRUPTED_CONTRACT");
  }
  return {
    validation_mode: EXACT_RESPONSE_CONTRACT_MODE,
    exact_response_evidence_disposition: "COMPLETE_EXACT_LITERAL_V1",
    worker_payload_revision_disposition: identityDispositions.workerPayloadRevisionDisposition,
    canonical_result_run_disposition: identityDispositions.canonicalResultRunDisposition,
    expected_literal: missionContract.expected_literal,
    expected_literal_sha256: missionContract.expected_literal_sha256,
    observed_literal_sha256: verifierEvidence.observed_response_sha256,
    semantic_success: true,
    assertion_count: checks.length,
    checks,
  };
}
