import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import {
  EXACT_RESPONSE_CONTRACT_MODE,
  LEGACY_M2A_LITERAL,
  NO_EXACT_RESPONSE_CONTRACT_MODE,
  NONAUTHORITATIVE_WORKER_REVISION_DISPOSITION,
  verifyRecoveryResultContractEvidence,
} from "./support/tsf-hq-dispatch-recovery-result-contract-proof.mjs";

let assertions = 0;
function check(value, message) { assertions += 1; assert.ok(value, message); }
function equal(actual, expected, message) { assertions += 1; assert.equal(actual, expected, message); }
function throwsCode(factory, code, message) {
  assertions += 1;
  assert.throws(factory, (error) => error instanceof Error && error.message.startsWith(`${code}:`), message);
}
function sha256(value) { return createHash("sha256").update(value, "utf8").digest("hex"); }
function clone(value) { return structuredClone(value); }

const identity = {
  mission_id: "recovery-new-mission-0001",
  mission_revision: 2,
  run_id: "canonical-result-recovery-new-mission-0001-2",
  result_id: "canonical-result-recovery-new-mission-0001-2",
};
const literal = "TSF_V1_CANONICAL_FIRST_LAUNCH_GREEN";
const queueHash = "b".repeat(64);
const workerHash = "c".repeat(64);
const adapterHash = "d".repeat(64);
const workerPath = "C:\\proof\\wr.json";
const adapterPath = "C:\\proof\\ar.json";
const canonicalAdapterPath = "C:\\proof\\preserved\\ar.json";
const registryPath = "C:\\proof\\pr.json";
const exactContract = {
  schema_version: "tsf_exact_literal_response_contract_v1",
  validation_mode: EXACT_RESPONSE_CONTRACT_MODE,
  expected_literal: literal,
  expected_literal_sha256: sha256(literal),
  semantic_contract_sha256: "a".repeat(64),
  mission_binding: { mission_id: identity.mission_id, mission_revision: identity.mission_revision },
};

function canonicalBindingChain(workerResult) {
  workerResult.schema_version = 1;
  workerResult.adapter_result_path = adapterPath;
  workerResult.adapter_result_sha256 = adapterHash;
  workerResult.observation_claims = { filesystem_writes: { classification: "OBSERVED_NOT_USED", value: false, source: "fixture", run_id: identity.run_id } };
  return {
    workerResultArtifact: { path: workerPath, sha256: workerHash },
    adapterArtifact: { path: adapterPath, sha256: adapterHash },
    canonicalAdapterArtifact: { path: canonicalAdapterPath, sha256: adapterHash },
    producerRegistryArtifact: { path: registryPath, sha256: "e".repeat(64) },
    lifecycle: { ...identity, schema_version: "tsf_lifecycle_terminal_result_v1", queue_document_sha256: queueHash, worker_result_path: workerPath, producer_registry_path: registryPath },
    adapter: { ...identity, schema_version: "tsf_codex_app_server_adapter_result_v1", queue_document_sha256: queueHash },
    producerRegistry: {
      schema_version: "tsf_producer_evidence_registry_v1",
      binding: { mission_id: identity.mission_id, mission_revision: identity.mission_revision, run_id: identity.run_id, queue_document_sha256: queueHash },
      artifacts: [{ logical_type: "worker_result", sha256: workerHash }],
    },
    preservationManifest: {
      schema_version: "tsf_runtime_artifact_manifest_v1",
      mission_id: identity.mission_id,
      mission_revision: identity.mission_revision,
      run_id: identity.run_id,
      artifacts: [
        { logical_type: "worker_result", sha256: workerHash },
        { logical_type: "adapter_result", sha256: adapterHash },
      ],
    },
    canonicalResult: { schema_version: "tsf_result_envelope_v1", mission_id: identity.mission_id, mission_revision: identity.mission_revision, result_id: identity.result_id },
  };
}

function exactFixture() {
  const evidence = {
    ...identity,
    validation_mode: EXACT_RESPONSE_CONTRACT_MODE,
    expected_literal: literal,
    observed_literal: literal,
    expected_response_sha256: sha256(literal),
    observed_response_sha256: sha256(literal),
    semantic_contract_sha256: exactContract.semantic_contract_sha256,
    transport_success: true,
    exact_match: true,
    semantic_success: true,
    independently_recomputed: true,
  };
  const verifierEvidence = clone(evidence);
  delete verifierEvidence.transport_success;
  delete verifierEvidence.semantic_success;
  const mission = { ...identity, exact_response_contract: clone(exactContract) };
  const queueDocument = {
    durable_mission: { ...identity, exact_response_contract: clone(exactContract) },
    mission_packet: { exact_response_contract: clone(exactContract) },
    worker_instruction_packet: { exact_response_contract: clone(exactContract), exact_task: `Return exactly ${literal}.` },
  };
  const workerResult = { mission_id: identity.mission_id, exact_response_evidence: evidence };
  const verifier = { ...identity, verdict: "GREEN", verified: true, exact_response_evidence: verifierEvidence };
  const admission = { status: "ADMITTED_WITH_CAVEATS", mission_id: identity.mission_id, mission_revision: identity.mission_revision, result_id: identity.result_id };
  const recoveryRun = { ...identity, state: admission.status, response_contract: clone(exactContract), worker: { exact_response: evidence }, verifier: { exact_response: verifierEvidence } };
  return { mission, queueDocument, workerResult, verifier, admission, recoveryRun, ...canonicalBindingChain(workerResult), interruptedSourceContract: null };
}

function generalFixture() {
  const mission = { ...identity, exact_response_contract: null };
  const queueDocument = {
    durable_mission: { ...identity, exact_response_contract: null },
    mission_packet: { exact_response_contract: null },
    worker_instruction_packet: { exact_response_contract: null, exact_task: "Read the bounded TSF-local fixture and return a concise factual result." },
  };
  const workerResult = {
    mission_id: identity.mission_id,
    role_output_contract_satisfied: true,
    exact_response_evidence: null,
    tests: { test_id: "hq-dispatch-general-result-v2", status: "PASS" },
  };
  const verifier = {
    ...identity,
    verdict: "GREEN",
    verified: true,
    exact_response_evidence: null,
    checks: [{ name: "postrun.mission_id", status: "PASS", passed: true }],
  };
  const admission = { status: "ADMITTED_WITH_CAVEATS", mission_id: identity.mission_id, mission_revision: identity.mission_revision, result_id: identity.result_id };
  const recoveryRun = { ...identity, state: admission.status, response_contract: null, worker: { exact_response: null }, verifier: { exact_response: null } };
  return { mission, queueDocument, workerResult, verifier, admission, recoveryRun, ...canonicalBindingChain(workerResult), interruptedSourceContract: null };
}

const exact = exactFixture();
const exactProof = verifyRecoveryResultContractEvidence(exact);
equal(exactProof.validation_mode, EXACT_RESPONSE_CONTRACT_MODE, "present contract selects exact proof mode");
equal(exactProof.exact_response_evidence_disposition, "COMPLETE_EXACT_LITERAL_V1", "present contract requires complete exact evidence");
check(exactProof.assertion_count >= 50, "exact proof executes the full fail-closed invariant set");

for (const [code, mutate, message] of [
  ["EXACT_VERIFIER_EVIDENCE_MISSING", (x) => { x.verifier.exact_response_evidence = null; }, "missing verifier exact evidence fails"],
  ["EXACT_VERIFIER_MISSION_REVISION_MISMATCH", (x) => { x.verifier.exact_response_evidence.mission_revision += 1; }, "wrong exact-evidence revision fails"],
  ["EXACT_CONTRACT_EXPECTED_HASH_RECOMPUTE_MISMATCH", (x) => { x.mission.exact_response_contract.expected_literal_sha256 = "0".repeat(64); }, "wrong expected hash fails"],
  ["EXACT_WORKER_SUBSTITUTED_LITERAL", (x) => { x.workerResult.exact_response_evidence.observed_literal = LEGACY_M2A_LITERAL; x.workerResult.exact_response_evidence.observed_response_sha256 = sha256(LEGACY_M2A_LITERAL); }, "substituted literal fails"],
]) {
  const value = exactFixture(); mutate(value); throwsCode(() => verifyRecoveryResultContractEvidence(value), code, message);
}

const general = generalFixture();
const generalProof = verifyRecoveryResultContractEvidence(general);
equal(generalProof.validation_mode, NO_EXACT_RESPONSE_CONTRACT_MODE, "absent contract selects explicit not-applicable proof mode");
equal(generalProof.exact_response_evidence_disposition, NO_EXACT_RESPONSE_CONTRACT_MODE, "null exact evidence is classified, not skipped");
check(generalProof.assertion_count >= 25, "general proof executes upstream, verifier, admission, and anti-fabrication invariants");
equal(generalProof.worker_payload_revision_disposition, NONAUTHORITATIVE_WORKER_REVISION_DISPOSITION, "raw V1 worker revision omission is explicitly classified as non-authoritative");
equal(generalProof.canonical_result_run_disposition, "RUN_ID_REPRESENTED_BY_CANONICAL_RESULT_ID", "canonical result run identity is represented by its required result_id");

for (const [code, mutate, message] of [
  ["GENERAL_MISSION_PACKET_CONTRACT_MUST_BE_ABSENT", (x) => { x.queueDocument.mission_packet.exact_response_contract = clone(exactContract); }, "null evidence requires every upstream contract to be absent"],
  ["GENERAL_RESULT_CONTAINS_M2A_FALLBACK_LITERAL", (x) => { x.queueDocument.worker_instruction_packet.exact_task += ` ${LEGACY_M2A_LITERAL}`; }, "M2A fallback insertion fails"],
  ["GENERAL_VERIFIER_MISSION_ID_MISMATCH", (x) => { x.verifier.mission_id = "stale-mission"; }, "ordinary verifier mission linkage remains required"],
  ["GENERAL_VERIFIER_MISSION_REVISION_MISMATCH", (x) => { x.verifier.mission_revision += 1; }, "ordinary verifier revision linkage remains required"],
  ["GENERAL_VERIFIER_RUN_ID_MISMATCH", (x) => { x.verifier.run_id = "stale-run"; }, "ordinary verifier run linkage remains required"],
  ["RECOVERY_ADMISSION_STATUS_INVALID", (x) => { x.admission.status = "REJECTED"; x.recoveryRun.state = "REJECTED"; }, "general admission still requires valid verification"],
  ["GENERAL_VERIFIER_FABRICATED_EXACT_RESPONSE_EVIDENCE", (x) => { x.verifier.exact_response_evidence = clone(exactFixture().verifier.exact_response_evidence); }, "fabricated exact verifier evidence fails"],
  ["GENERAL_WORKER_FABRICATED_EXACT_RESPONSE_EVIDENCE", (x) => { x.workerResult.exact_response_evidence = clone(exactFixture().workerResult.exact_response_evidence); }, "stale exact worker evidence from interrupted run fails"],
]) {
  const value = generalFixture(); mutate(value); throwsCode(() => verifyRecoveryResultContractEvidence(value), code, message);
}

for (const [code, mutate, message] of [
  ["PRODUCER_REGISTRY_WORKER_RESULT_ARTIFACT_CARDINALITY_INVALID", (x) => { x.producerRegistry.artifacts = []; }, "missing worker registry binding fails"],
  ["PRODUCER_REGISTRY_WORKER_HASH_MISMATCH", (x) => { x.producerRegistry.artifacts[0].sha256 = "0".repeat(64); }, "worker byte substitution fails registry binding"],
  ["CANONICAL_ADAPTER_COPY_HASH_MISMATCH", (x) => { x.canonicalAdapterArtifact.sha256 = "0".repeat(64); }, "preserved adapter copy must match the worker-bound adapter bytes"],
  ["ADAPTER_MISSION_REVISION_MISMATCH", (x) => { x.adapter.mission_revision += 1; }, "adapter revision mismatch fails"],
  ["CANONICAL_RESULT_MISSION_REVISION_MISMATCH", (x) => { x.canonicalResult.mission_revision += 1; }, "canonical result revision mismatch fails"],
  ["CANONICAL_RESULT_RESULT_ID_MISMATCH", (x) => { x.canonicalResult.result_id = "stale-result"; }, "canonical result cannot substitute another run/result"],
  ["CANONICAL_RESULT_OPTIONAL_RUN_ID_MISMATCH", (x) => { x.canonicalResult.run_id = "stale-run"; }, "contradictory optional canonical run ID fails"],
  ["WORKER_ROOT_MISSION_REVISION_MISMATCH", (x) => { x.workerResult.mission_revision = identity.mission_revision + 1; }, "contradictory optional worker root revision fails"],
  ["WORKER_ROOT_RUN_ID_MISMATCH", (x) => { x.workerResult.run_id = "stale-run"; }, "contradictory optional worker root run fails"],
  ["WORKER_OBSERVATION_CLAIM_RUN_ID_MISMATCH", (x) => { x.workerResult.observation_claims.filesystem_writes.run_id = "stale-run"; }, "cross-run observation claim fails"],
  ["WORKER_RESULT_SCHEMA_VERSION_UNSUPPORTED", (x) => { x.workerResult.schema_version = 2; }, "unsupported worker schema fails closed"],
  ["PRODUCER_REGISTRY_BINDING_MISSION_REVISION_MISMATCH", (x) => { x.producerRegistry.binding.mission_revision += 1; }, "revision-one bytes cannot satisfy an unbound revision-two registry"],
  ["PRESERVATION_MANIFEST_MISSION_REVISION_MISMATCH", (x) => { x.preservationManifest.mission_revision += 1; }, "preservation cross-revision substitution fails"],
]) {
  const value = generalFixture(); mutate(value); throwsCode(() => verifyRecoveryResultContractEvidence(value), code, message);
}

const exactOriginalGeneralRecovery = generalFixture();
exactOriginalGeneralRecovery.interruptedSourceContract = clone(exactContract);
equal(verifyRecoveryResultContractEvidence(exactOriginalGeneralRecovery).validation_mode, NO_EXACT_RESPONSE_CONTRACT_MODE, "cross-revision exact-to-general recovery derives expectations from the new revision");

const oldContract = clone(exactContract);
oldContract.expected_literal = LEGACY_M2A_LITERAL;
oldContract.expected_literal_sha256 = sha256(LEGACY_M2A_LITERAL);
oldContract.semantic_contract_sha256 = "b".repeat(64);
const generalOriginalExactRecovery = exactFixture();
generalOriginalExactRecovery.interruptedSourceContract = oldContract;
equal(verifyRecoveryResultContractEvidence(generalOriginalExactRecovery).validation_mode, EXACT_RESPONSE_CONTRACT_MODE, "cross-revision general-to-exact recovery validates only the new canonical contract");

const staleExactRecovery = exactFixture();
staleExactRecovery.interruptedSourceContract = oldContract;
for (const target of [staleExactRecovery.workerResult.exact_response_evidence, staleExactRecovery.verifier.exact_response_evidence, staleExactRecovery.recoveryRun.worker.exact_response, staleExactRecovery.recoveryRun.verifier.exact_response]) {
  target.expected_literal = oldContract.expected_literal;
  target.observed_literal = oldContract.expected_literal;
  target.expected_response_sha256 = oldContract.expected_literal_sha256;
  target.observed_response_sha256 = oldContract.expected_literal_sha256;
  target.semantic_contract_sha256 = oldContract.semantic_contract_sha256;
}
throwsCode(() => verifyRecoveryResultContractEvidence(staleExactRecovery), "EXACT_WORKER_EXPECTED_LITERAL_MISMATCH", "stale exact evidence copied from the interrupted contract fails against the new revision");

process.stdout.write(`${JSON.stringify({ schema_version: "tsf_hq_dispatch_recovery_result_contract_proof_test_v1", status: "PASS", assertions, exact_invariant_assertions: exactProof.assertion_count, general_invariant_assertions: generalProof.assertion_count, modes: [EXACT_RESPONSE_CONTRACT_MODE, NO_EXACT_RESPONSE_CONTRACT_MODE] }, null, 2)}\n`);
