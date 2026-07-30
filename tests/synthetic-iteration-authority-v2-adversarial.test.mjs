import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import path from "node:path";

import {
  AuthorityV2Error,
  FIXTURE_ROOT,
  consumePreauthorizedTaskBinding,
  closedEnvironment,
  createPreauthorizedTaskBinding,
  createApprovedBuilderCandidateSet,
  createCandidateIntegrityProof,
  createApprovedWriteset,
  createTaskPreauthorization,
  executeAllowedCommand,
  getBuilderCandidateContent,
  identityRecord,
  loadAuthority,
  matchPreauthorizedTaskBinding,
  sha256,
  assertApprovedCandidateBytes,
  assertNoDuplicateJsonMembers,
  validateAllowedPath,
  validateCommandInvocation,
  validateCommitAuthority,
  validateApprovedBuilderCandidateSet,
  validateApprovedWriteset,
  validateRecoveryState,
  validateRegistrationRecord,
} from "../tools/hq-dispatch/v1/synthetic-iteration-authority-v2.mjs";

const authority = loadAuthority();
const task = authority.tasks[0];

function registrationFixture() {
  return identityRecord({
    schema_version: "SYNTHETIC_REPOSITORY_REGISTRATION_V2",
    registration_id: "synthetic-registration-adversarial",
    program_id: authority.program_id,
    action_id: authority.action_id,
    execution_context_identity_sha256:
      authority.pilot_execution_contexts.contexts.EXACT_CANDIDATE.context_identity_sha256,
    repository_root: authority.repository.root,
    git_top_level: authority.repository.root,
    branch: authority.repository.branch,
    baseline_commit: "a".repeat(40),
    baseline_tree: "b".repeat(40),
    baseline_subject: authority.repository.baseline_subject,
    file_inventory: [...authority.repository.allowed_paths].sort(),
    file_hashes: Object.fromEntries(authority.repository.allowed_paths.map((relative) => [relative, "c".repeat(64)])),
    remote_count: 0,
    registered_at: "2026-07-29T00:00:00.000Z",
    expires_at: authority.expires_at,
    contract_version: authority.contract_version,
  }, "registration_identity_sha256");
}

function reidentity(value, field) {
  const copy = structuredClone(value);
  delete copy[field];
  return identityRecord(copy, field);
}

function expectCode(fn, code, disposition = "BLOCKED") {
  assert.throws(fn, (error) => {
    assert.ok(error instanceof AuthorityV2Error);
    assert.equal(error.code, code);
    assert.equal(error.disposition, disposition);
    return true;
  });
}

function changedRegistration(field, value) {
  const candidate = registrationFixture();
  candidate[field] = value;
  return reidentity(candidate, "registration_identity_sha256");
}

function command(executable, arguments_, workingDirectory = FIXTURE_ROOT) {
  return { executable, arguments: arguments_, working_directory: workingDirectory };
}

function candidateContext(selectedTask = task, iteration = 1) {
  const registration = registrationFixture();
  const preauthorization = createTaskPreauthorization(authority, registration, selectedTask.task_id);
  const binding = createPreauthorizedTaskBinding(authority, registration, preauthorization);
  const candidateSet = createApprovedBuilderCandidateSet(
    authority,
    registration,
    selectedTask,
    preauthorization,
    iteration,
    selectedTask.authorized_source_paths[0],
  );
  const content = getBuilderCandidateContent(selectedTask.task_id, iteration);
  const writeset = createApprovedWriteset({
    authority,
    registration,
    task: selectedTask,
    preauthorization,
    binding,
    candidateSet,
    iteration,
    runId: `${selectedTask.task_id}-iteration-${iteration}-adversarial`,
    relativePath: selectedTask.authorized_source_paths[0],
    beforeSha256: sha256(readFileSync(path.join(
      FIXTURE_ROOT,
      ...selectedTask.authorized_source_paths[0].split("/"),
    ))),
    content,
    candidateArtifactRelativePath: `tasks/${selectedTask.task_id}/iteration-${iteration}/replacement.bin`,
  });
  return { registration, preauthorization, binding, candidateSet, content, writeset };
}

function commitAuthorityFixture(overrides = {}) {
  return identityRecord({
    schema_version: "SYNTHETIC_TASK_COMMIT_AUTHORITY_V2",
    program_id: authority.program_id,
    task_id: task.task_id,
    registration_identity_sha256: "1".repeat(64),
    preauthorization_identity_sha256: "4".repeat(64),
    execution_context_identity_sha256:
      authority.pilot_execution_contexts.contexts.EXACT_CANDIDATE.context_identity_sha256,
    binding_identity_sha256: "2".repeat(64),
    verifier_identity_sha256: "3".repeat(64),
    approved_candidate_set_identity_sha256: "5".repeat(64),
    writeset_identity_sha256: "6".repeat(64),
    byte_observation_identity_sha256: "7".repeat(64),
    approved_replacement_sha256: task.approved_builder_candidate_sets[0].candidates[0].sha256,
    replacement_byte_length: task.approved_builder_candidate_sets[0].candidates[0].byte_length,
    expected_file_mode: "100644",
    baseline_commit: "a".repeat(40),
    baseline_tree: "b".repeat(40),
    iteration: 1,
    run_id: `${task.task_id}-iteration-1-unit`,
    focused_tests_passed: true,
    acceptance_tests_passed: true,
    verifier_verdict: "GREEN",
    changed_paths: [...task.authorized_source_paths].sort(),
    unrelated_paths_clean: true,
    unexpected_untracked_paths: [],
    commit_subject: task.required_commit_subject,
    remote_count: 0,
    push_performed: false,
    amend: false,
    use_count: 0,
    expires_at: authority.expires_at,
    ...overrides,
  }, "commit_authority_identity_sha256");
}

test("registration matrix rejects identity and scope changes", () => {
  const valid = registrationFixture();
  assert.equal(validateRegistrationRecord(valid, authority, { now: new Date("2026-07-29T01:00:00Z") }).valid, true);
  for (const [field, value, code] of [
    ["repository_root", "C:\\TSF_SYNTHETIC_ITERATION_V2", "REGISTRATION_ROOT_CHANGED"],
    ["repository_root", "C:\\TSF_SYNTHETIC_ITERATION_V2\\sibling", "REGISTRATION_ROOT_CHANGED"],
    ["git_top_level", "C:\\TSF_SYNTHETIC_ITERATION_V2", "REGISTRATION_GIT_TOP_CHANGED"],
    ["branch", "pilot/different", "REGISTRATION_BRANCH_CHANGED"],
    ["baseline_commit", "not-a-commit", "REGISTRATION_BASELINE_INVALID"],
    ["remote_count", 1, "REGISTRATION_REMOTE_PRESENT"],
  ]) {
    expectCode(
      () => validateRegistrationRecord(changedRegistration(field, value), authority, { now: new Date("2026-07-29T01:00:00Z") }),
      code,
      "TIM_REQUIRED",
    );
  }
  const expired = changedRegistration("expires_at", "2026-07-28T23:59:59Z");
  expectCode(
    () => validateRegistrationRecord(expired, authority, { now: new Date("2026-07-29T01:00:00Z") }),
    "REGISTRATION_EXPIRED",
    "TIM_REQUIRED",
  );
});

test("preauthorization cannot be widened, substituted, or replayed", () => {
  const registration = registrationFixture();
  const exact = createTaskPreauthorization(authority, registration, task.task_id);
  const binding = createPreauthorizedTaskBinding(authority, registration, exact);
  const mutations = [
    (candidate) => { candidate.goal = `${candidate.goal} widened`; },
    (candidate) => { candidate.authorized_source_paths.push("src/extra.mjs"); },
    (candidate) => { candidate.required_focused_tests = []; },
    (candidate) => { candidate.authorized_command_templates[0].arguments = ["--eval", "unsafe"]; },
    (candidate) => { candidate.maximum_iterations = 4; },
    (candidate) => { candidate.required_commit_subject = "fix: different"; },
    (candidate) => { candidate.repository_root = "C:\\different"; },
    (candidate) => { candidate.branch = "pilot/different"; },
    (candidate) => { candidate.caller_supplied_approval = true; },
  ];
  for (const mutate of mutations) {
    const candidate = structuredClone(exact);
    mutate(candidate);
    expectCode(
      () => createPreauthorizedTaskBinding(authority, registration, candidate),
      "PREAUTHORIZATION_TEMPLATE_MISMATCH",
      "TIM_REQUIRED",
    );
  }
  expectCode(
    () => matchPreauthorizedTaskBinding(authority, registration, exact, binding, authority.tasks[1].task_id),
    "CROSS_TASK_BINDING",
    "TIM_REQUIRED",
  );
  const consumed = new Set();
  assert.equal(consumePreauthorizedTaskBinding(binding, consumed).consumed, true);
  expectCode(
    () => consumePreauthorizedTaskBinding(binding, consumed),
    "PREAUTHORIZED_BINDING_REPLAYED",
    "TIM_REQUIRED",
  );
});

test("allowlist matching is exact and case-sensitive", () => {
  assert.equal(
    validateAllowedPath({
      repositoryRoot: FIXTURE_ROOT,
      relativePath: task.authorized_source_paths[0],
      allowlist: task.authorized_source_paths,
      requireExisting: true,
    }).normalized,
    task.authorized_source_paths[0],
  );
  expectCode(
    () => validateAllowedPath({
      repositoryRoot: FIXTURE_ROOT,
      relativePath: "SRC/path-containment.mjs",
      allowlist: task.authorized_source_paths,
      requireExisting: false,
    }),
    "PATH_NOT_EXACTLY_ALLOWLISTED",
  );
  expectCode(
    () => validateAllowedPath({
      repositoryRoot: FIXTURE_ROOT,
      relativePath: "src/.git/config",
      allowlist: ["src/.git/config"],
      requireExisting: false,
    }),
    "DIRECT_GIT_PATH_PROHIBITED",
  );
});

test("closed command templates admit exact local commands", () => {
  for (const invocation of [
    command("node", ["--test", task.focused_tests[0]]),
    command("node", ["--test", task.acceptance_tests[0]]),
    command("node", ["--check", task.authorized_source_paths[0]]),
    command("git", ["status", "--porcelain=v2"]),
    command("git", ["diff", "--check"]),
    command("git", ["diff", "--name-only"]),
    command("git", ["rev-parse", "HEAD"]),
  ]) {
    assert.ok(validateCommandInvocation(authority, task, invocation).template_id);
  }
});

test("command injection, network, package, and destructive Git forms reject before launch", () => {
  const invalid = [
    command("cmd.exe", ["/c", "dir"]),
    command("node", ["--test", "test/a.mjs&&whoami"]),
    command("node", ["--test", "test/a.mjs>out"]),
    command("node", ["--test", "test/*.mjs"]),
    command("node", ["--test", "$HOME/test.mjs"]),
    command("npm", ["install"]),
    command("git", ["push", "origin", "HEAD"]),
    command("git", ["remote", "add", "origin", "https://example.invalid/repo"]),
    command("git", ["reset", "--hard"]),
    command("git", ["clean", "-fd"]),
    command("git", ["status", "--porcelain=v2"], "C:\\TSF_SYNTHETIC_ITERATION_V2"),
  ];
  for (const invocation of invalid) {
    assert.throws(() => validateCommandInvocation(authority, task, invocation), AuthorityV2Error);
  }
});

test("command execution ignores inherited PATH and credential-like variables", () => {
  const priorPath = process.env.PATH;
  const priorToken = process.env.GITHUB_TOKEN;
  process.env.PATH = "C:\\definitely-not-a-real-command-root";
  process.env.GITHUB_TOKEN = "sentinel-must-not-be-inherited";
  try {
    const childEnvironment = closedEnvironment();
    assert.equal(childEnvironment.PATH, "");
    assert.equal(Object.hasOwn(childEnvironment, "GITHUB_TOKEN"), false);
    expectCode(
      () => closedEnvironment({ GITHUB_TOKEN: "substitution" }),
      "PROCESS_ENVIRONMENT_KEY_NOT_ALLOWLISTED",
    );
    const receipt = executeAllowedCommand(authority, task, command("git", ["status", "--porcelain=v2"]));
    assert.equal(receipt.exit_code, 0);
    assert.equal(receipt.executable_path, authority.executables.git.path);
    assert.equal(receipt.executable_sha256, authority.executables.git.sha256);
  } finally {
    if (priorPath === undefined) delete process.env.PATH;
    else process.env.PATH = priorPath;
    if (priorToken === undefined) delete process.env.GITHUB_TOKEN;
    else process.env.GITHUB_TOKEN = priorToken;
  }
});

test("commit authority requires complete GREEN evidence and exact single use", () => {
  assert.equal(validateCommitAuthority(authority, task, commitAuthorityFixture()).valid, true);
  for (const [overrides, code] of [
    [{ focused_tests_passed: false }, "COMMIT_BEFORE_FOCUSED_TESTS"],
    [{ acceptance_tests_passed: false }, "COMMIT_BEFORE_ACCEPTANCE_TESTS"],
    [{ verifier_verdict: "RED" }, "COMMIT_BEFORE_VERIFIER_GREEN"],
    [{ changed_paths: [...task.authorized_source_paths, "README.md"].sort() }, "COMMIT_CHANGED_PATH_SET_INVALID"],
    [{ unrelated_paths_clean: false }, "COMMIT_UNRELATED_PATHS_DIRTY"],
    [{ commit_subject: "fix: wrong" }, "COMMIT_SUBJECT_CHANGED"],
    [{ use_count: 1 }, "COMMIT_AUTHORITY_REPLAY_OR_AMEND"],
    [{ amend: true }, "COMMIT_AUTHORITY_REPLAY_OR_AMEND"],
    [{ push_performed: true }, "COMMIT_REMOTE_OR_PUSH_PRESENT"],
    [{ remote_count: 1 }, "COMMIT_REMOTE_OR_PUSH_PRESENT"],
  ]) {
    expectCode(() => validateCommitAuthority(authority, task, commitAuthorityFixture(overrides)), code);
  }
});

test("recovery is bound to exact task, writeset, baseline, run, and non-automation posture", () => {
  const registration = registrationFixture();
  const preauthorization = createTaskPreauthorization(authority, registration, task.task_id);
  const binding = createPreauthorizedTaskBinding(authority, registration, preauthorization);
  const candidateSet = createApprovedBuilderCandidateSet(
    authority,
    registration,
    task,
    preauthorization,
    1,
    task.authorized_source_paths[0],
  );
  const content = getBuilderCandidateContent(task.task_id, 1);
  const writeset = createApprovedWriteset({
    authority,
    registration,
    task,
    preauthorization,
    binding,
    candidateSet,
    iteration: 1,
    runId: `${task.task_id}-iteration-1-original`,
    relativePath: task.authorized_source_paths[0],
    beforeSha256: sha256(readFileSync(path.join(
      FIXTURE_ROOT,
      ...task.authorized_source_paths[0].split("/"),
    ))),
    content,
    candidateArtifactRelativePath: `tasks/${task.task_id}/iteration-1/replacement.bin`,
  });
  assert.equal(
    validateApprovedWriteset(
      authority,
      registration,
      task,
      preauthorization,
      binding,
      candidateSet,
      writeset,
      { replacementBytes: Buffer.from(content, "utf8") },
    ).valid,
    true,
  );
  const valid = identityRecord({
    schema_version: "SYNTHETIC_WRITE_RECOVERY_STATE_V2",
    program_id: authority.program_id,
    task_id: task.task_id,
    repository_root: registration.repository_root,
    branch: registration.branch,
    baseline_commit: binding.baseline_commit,
    baseline_tree: binding.baseline_tree,
    registration_identity_sha256: registration.registration_identity_sha256,
    preauthorization_identity_sha256: preauthorization.preauthorization_identity_sha256,
    execution_context_identity_sha256: registration.execution_context_identity_sha256,
    binding_identity_sha256: binding.binding_identity_sha256,
    candidate_set_identity_sha256: candidateSet.candidate_set_identity_sha256,
    candidate_set_relative_path: `tasks/${task.task_id}/iteration-1/approved-candidate-set.json`,
    candidate_set_file_sha256: "3".repeat(64),
    writeset_identity_sha256: writeset.writeset_identity_sha256,
    writeset_relative_path: `tasks/${task.task_id}/iteration-1/approved-writeset.json`,
    writeset_file_sha256: "4".repeat(64),
    iteration: 1,
    original_run_id: writeset.run_id,
    recovery_run_id: `${task.task_id}-recovery-unit`,
    source_relative_path: task.authorized_source_paths[0],
    preimage_relative_path: `tasks/${task.task_id}/iteration-1/preimage.bin`,
    preimage_sha256: writeset.writes[0].before_sha256,
    replacement_relative_path: `tasks/${task.task_id}/iteration-1/replacement.bin`,
    replacement_sha256: writeset.writes[0].approved_replacement_sha256,
    replacement_byte_length: writeset.writes[0].replacement_byte_length,
    recovery_receipt_relative_path: `tasks/${task.task_id}/iteration-1/recovery-receipt.json`,
    interruption_point: "PRE_WRITE_CHECKPOINT_FOR_ATOMIC_REPLACEMENT",
    repository_condition: "PREIMAGE_PRESENT_WRITE_NOT_STARTED",
    pre_iteration_sha256: writeset.writes[0].before_sha256,
    expected_replacement_sha256: writeset.writes[0].approved_replacement_sha256,
    authorized_disposition: "COMPLETE_EXACT_APPROVED_REPLACEMENT",
    auto_admitted: false,
    auto_rerun: false,
  }, "recovery_identity_sha256");
  assert.equal(
    validateRecoveryState(
      authority,
      registration,
      task,
      preauthorization,
      binding,
      candidateSet,
      writeset,
      valid,
    ).valid,
    true,
  );
  for (const [field, value, code, disposition] of [
    ["baseline_commit", "9".repeat(40), "RECOVERY_BASELINE_CHANGED", "BLOCKED"],
    ["writeset_identity_sha256", "f".repeat(64), "RECOVERY_WRITESET_IDENTITY_CHANGED", "BLOCKED"],
    ["iteration", 2, "RECOVERY_ITERATION_CHANGED", "EXHAUSTED"],
    ["original_run_id", `${task.task_id}-iteration-1-substituted`, "RECOVERY_ORIGINAL_RUN_CHANGED", "BLOCKED"],
    ["recovery_run_id", valid.original_run_id, "RECOVERY_RUN_ID_REUSED", "BLOCKED"],
    ["repository_condition", "AMBIGUOUS", "RECOVERY_REPOSITORY_CONDITION_CHANGED", "BLOCKED"],
    ["authorized_disposition", "WIDEN_SCOPE", "RECOVERY_SCOPE_BROADENED", "BLOCKED"],
    ["auto_admitted", true, "RECOVERY_AUTOMATION_SCOPE_WIDENED", "BLOCKED"],
    ["auto_rerun", true, "RECOVERY_AUTOMATION_SCOPE_WIDENED", "BLOCKED"],
  ]) {
    const candidate = structuredClone(valid);
    candidate[field] = value;
    const rebound = reidentity(candidate, "recovery_identity_sha256");
    expectCode(
      () => validateRecoveryState(
        authority,
        registration,
        task,
        preauthorization,
        binding,
        candidateSet,
        writeset,
        rebound,
      ),
      code,
      disposition,
    );
  }
});

test("registration hash keys cannot substitute same-count paths", () => {
  const candidate = registrationFixture();
  delete candidate.file_hashes["README.md"];
  candidate.file_hashes["outside.txt"] = "d".repeat(64);
  const rebound = reidentity(candidate, "registration_identity_sha256");
  expectCode(
    () => validateRegistrationRecord(rebound, authority, { now: new Date("2026-07-29T01:00:00Z") }),
    "REGISTRATION_FILE_HASH_KEYS_CHANGED",
    "TIM_REQUIRED",
  );
});

test("all-a coherent writeset reidentity cannot create replacement authority", () => {
  const context = candidateContext();
  const attacked = structuredClone(context.writeset);
  attacked.writes[0].approved_replacement_sha256 = "a".repeat(64);
  attacked.writes[0].candidate_artifact_sha256 = "a".repeat(64);
  const rebound = reidentity(attacked, "writeset_identity_sha256");
  expectCode(
    () => validateApprovedWriteset(
      authority,
      context.registration,
      task,
      context.preauthorization,
      context.binding,
      context.candidateSet,
      rebound,
    ),
    "REPLACEMENT_SHA_NOT_IN_APPROVED_BUILDER_CANDIDATE_SET",
  );
});

test("persisted or caller-created candidate-set substitution cannot rebind authority", () => {
  const context = candidateContext();
  const substituted = structuredClone(context.candidateSet);
  substituted.candidates[0].sha256 = "a".repeat(64);
  substituted.candidates[0].byte_length = 64;
  const rebound = reidentity(substituted, "candidate_set_identity_sha256");
  expectCode(
    () => validateApprovedBuilderCandidateSet(
      authority,
      context.registration,
      task,
      context.preauthorization,
      rebound,
    ),
    "APPROVED_CANDIDATE_SET_CANONICAL_MISMATCH",
  );

  const callerCreated = identityRecord({
    ...structuredClone(context.candidateSet),
    candidates: [{
      sha256: "b".repeat(64),
      byte_length: 7,
      provenance: "STATIC_BUILDER_CANDIDATE_V2",
      generation_run_identity: `${task.task_id}-builder-generation-1`,
    }],
  }, "candidate_set_identity_sha256");
  expectCode(
    () => validateApprovedBuilderCandidateSet(
      authority,
      context.registration,
      task,
      context.preauthorization,
      callerCreated,
    ),
    "APPROVED_CANDIDATE_SET_CANONICAL_MISMATCH",
  );
});

test("candidate membership is task path and iteration specific", () => {
  const task1 = candidateContext(authority.tasks[0], 1);
  const task2Iteration1 = candidateContext(authority.tasks[1], 1);
  const task2Iteration2 = candidateContext(authority.tasks[1], 2);

  expectCode(
    () => validateApprovedBuilderCandidateSet(
      authority,
      task2Iteration1.registration,
      authority.tasks[1],
      task2Iteration1.preauthorization,
      task1.candidateSet,
    ),
    "APPROVED_CANDIDATE_SET_TASK_CHANGED",
  );

  const wrongPath = structuredClone(task1.candidateSet);
  wrongPath.repository_relative_path = "src/job-admission.mjs";
  const wrongPathRebound = reidentity(wrongPath, "candidate_set_identity_sha256");
  expectCode(
    () => validateApprovedBuilderCandidateSet(
      authority,
      task1.registration,
      authority.tasks[0],
      task1.preauthorization,
      wrongPathRebound,
    ),
    "APPROVED_CANDIDATE_SET_PATH_CHANGED",
  );

  expectCode(
    () => createApprovedWriteset({
      authority,
      registration: task2Iteration2.registration,
      task: authority.tasks[1],
      preauthorization: task2Iteration2.preauthorization,
      binding: task2Iteration2.binding,
      candidateSet: task2Iteration2.candidateSet,
      iteration: 2,
      runId: `${authority.tasks[1].task_id}-iteration-2-cross-iteration`,
      relativePath: authority.tasks[1].authorized_source_paths[0],
      beforeSha256: sha256(readFileSync(path.join(
        FIXTURE_ROOT,
        ...authority.tasks[1].authorized_source_paths[0].split("/"),
      ))),
      content: task2Iteration1.content,
      candidateArtifactRelativePath: `tasks/${authority.tasks[1].task_id}/iteration-2/replacement.bin`,
    }),
    "REPLACEMENT_SHA_NOT_IN_APPROVED_BUILDER_CANDIDATE_SET",
  );
});

test("actual bytes and duplicate JSON members fail closed", () => {
  const context = candidateContext();
  assert.equal(
    assertApprovedCandidateBytes(
      context.candidateSet,
      context.writeset,
      Buffer.from(context.content, "utf8"),
    ).sha256,
    context.candidateSet.candidates[0].sha256,
  );
  expectCode(
    () => assertApprovedCandidateBytes(
      context.candidateSet,
      context.writeset,
      Buffer.from(`${context.content}tampered`, "utf8"),
      "REPLACEMENT_BYTES_MISMATCH",
    ),
    "REPLACEMENT_BYTES_MISMATCH",
  );
  expectCode(
    () => assertNoDuplicateJsonMembers('{"valid":false,"valid":true}', "RECOVERY_ARTIFACT_DUPLICATE_JSON_MEMBER"),
    "RECOVERY_ARTIFACT_DUPLICATE_JSON_MEMBER",
  );
});

test("temporary written pre-test staged and committed byte mismatches reject", () => {
  const context = candidateContext();
  const approved = context.writeset.writes[0].approved_replacement_sha256;
  const byteObservation = identityRecord({
    schema_version: "TSF_SYNTHETIC_CANDIDATE_BYTE_OBSERVATION_V2",
    execution_context_identity_sha256: context.registration.execution_context_identity_sha256,
    candidate_set_identity_sha256: context.candidateSet.candidate_set_identity_sha256,
    writeset_identity_sha256: context.writeset.writeset_identity_sha256,
    candidate_artifact_sha256: approved,
    temporary_file_sha256: approved,
    post_write_file_sha256: approved,
    pre_test_file_sha256: approved,
    post_test_file_sha256: approved,
  }, "byte_observation_identity_sha256");
  const precommitVerifier = { verifier_identity_sha256: "8".repeat(64) };
  const commitReceipt = identityRecord({
    commit_receipt_identity_sha256: "placeholder",
    working_tree_before_stage_sha256: approved,
    working_tree_before_commit_sha256: approved,
    working_tree_after_commit_sha256: approved,
    staged_blob: {
      phase: "STAGED",
      relative_path: context.writeset.writes[0].relative_path,
      git_object_id: "1".repeat(40),
      git_mode: "100644",
      content_sha256: approved,
      byte_length: context.writeset.writes[0].replacement_byte_length,
    },
    committed_blob: {
      phase: "COMMITTED",
      relative_path: context.writeset.writes[0].relative_path,
      git_object_id: "2".repeat(40),
      git_mode: "100644",
      content_sha256: approved,
      byte_length: context.writeset.writes[0].replacement_byte_length,
    },
    commit: "3".repeat(40),
  }, "commit_receipt_identity_sha256");
  assert.ok(createCandidateIntegrityProof(
    context.candidateSet,
    context.writeset,
    byteObservation,
    precommitVerifier,
    commitReceipt,
  ).candidate_integrity_proof_identity_sha256);

  for (const field of [
    "candidate_artifact_sha256",
    "temporary_file_sha256",
    "post_write_file_sha256",
    "pre_test_file_sha256",
    "post_test_file_sha256",
  ]) {
    const changed = structuredClone(byteObservation);
    changed[field] = "a".repeat(64);
    const rebound = reidentity(changed, "byte_observation_identity_sha256");
    expectCode(
      () => createCandidateIntegrityProof(
        context.candidateSet,
        context.writeset,
        rebound,
        precommitVerifier,
        commitReceipt,
      ),
      "CANDIDATE_INTEGRITY_BOUNDARY_HASH_MISMATCH",
    );
  }

  for (const field of ["staged_blob", "committed_blob"]) {
    const changed = structuredClone(commitReceipt);
    changed[field].content_sha256 = "a".repeat(64);
    const rebound = reidentity(changed, "commit_receipt_identity_sha256");
    expectCode(
      () => createCandidateIntegrityProof(
        context.candidateSet,
        context.writeset,
        byteObservation,
        precommitVerifier,
        rebound,
      ),
      "CANDIDATE_INTEGRITY_BOUNDARY_HASH_MISMATCH",
    );
  }
});

test("missing canonical candidate evidence rejects regardless of passing-looking descendants", () => {
  const context = candidateContext();
  expectCode(
    () => validateApprovedWriteset(
      authority,
      context.registration,
      task,
      context.preauthorization,
      context.binding,
      null,
      context.writeset,
    ),
    "APPROVED_CANDIDATE_SET_REQUIRED",
  );
});

test("fixture source inventory remains readable without out-of-root inspection", () => {
  for (const relative of authority.repository.allowed_paths) {
    const full = path.join(FIXTURE_ROOT, ...relative.split("/"));
    assert.ok(readFileSync(full).length > 0);
  }
  const source = readFileSync(path.join(FIXTURE_ROOT, "src", "path-containment.mjs"));
  assert.equal(sha256(source).length, 64);
});
