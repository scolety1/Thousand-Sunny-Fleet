import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

import {
  AuthorityV2Error,
  authorizeBuilderIteration,
  canonicalJson,
  createApprovedBuilderCandidateSet,
  createPreauthorizedTaskBinding,
  createTaskPreauthorization,
  identityRecord,
  loadAuthority,
  normalizeRepositoryRelativePath,
  transitionIteration,
  validateApprovedBuilderCandidateSet,
  validateAuthority,
  validateRegistrationRecord,
} from "../tools/hq-dispatch/v1/synthetic-iteration-authority-v2.mjs";

function registrationFixture(authority) {
  return identityRecord({
    schema_version: "SYNTHETIC_REPOSITORY_REGISTRATION_V2",
    registration_id: "synthetic-registration-unit-test",
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

function expectAuthorityError(fn, code, disposition = "BLOCKED") {
  assert.throws(fn, (error) => {
    assert.ok(error instanceof AuthorityV2Error);
    assert.equal(error.code, code);
    assert.equal(error.disposition, disposition);
    return true;
  });
}

test("static V2 authority remains closed and exact", () => {
  const authority = loadAuthority();
  const result = validateAuthority(authority);
  assert.equal(result.valid, true);
  assert.equal(authority.tasks.length, 3);
  assert.equal(authority.repository.allowed_paths.length, 13);
  assert.equal(authority.command_templates.length, 13);
  assert.deepEqual(
    authority.pilot_execution_contexts.invocation_contexts,
    {
      pilot: "EXACT_CANDIDATE",
      "archive-and-pilot": "EXACT_CANDIDATE",
      "archive-and-replay": "EXACT_CANDIDATE",
      "canonical-postmerge-pilot": "EXACT_CANONICAL_POSTMERGE",
    },
  );
  assert.equal(Object.keys(authority.pilot_execution_contexts.contexts).length, 2);
  assert.equal(authority.executables.node.path, "C:\\Program Files\\nodejs\\node.exe");
  assert.equal(authority.executables.git.path, "C:\\Program Files\\Git\\cmd\\git.exe");
  assert.ok(authority.tasks.every((task) => task.approved_builder_candidate_sets.every(
    (template, index) => template.iteration === index + 1
      && template.repository_relative_path === task.authorized_source_paths[0]
      && template.candidates.every(
        (candidate) => /^[a-f0-9]{64}$/.test(candidate.sha256)
          && candidate.byte_length > 0
          && candidate.provenance === "STATIC_BUILDER_CANDIDATE_V2",
      ),
  )));
  assert.equal(authority.iteration_states.length, 20);
  assert.ok(authority.command_templates.every((template) => template.contract_version === "APPROVED_COMMAND_TEMPLATE_V2"));
  assert.ok(Object.values(authority.prohibitions).every(Boolean));
});

test("runtime evidence contracts require the execution-context identity end to end", () => {
  const schema = JSON.parse(readFileSync(
    new URL(
      "../fleet/control/synthetic-iteration-v2/synthetic-iteration-runtime-contracts.schema.v2.json",
      import.meta.url,
    ),
    "utf8",
  ));
  for (const definition of [
    "registration",
    "preauthorization",
    "binding",
    "iteration",
    "candidateSet",
    "writeset",
    "commitAuthority",
    "recoveryState",
    "verifier",
    "byteObservation",
    "candidateIntegrityProof",
    "commitReceipt",
    "admissionBundle",
  ]) {
    assert.ok(
      schema.$defs[definition].required.includes("execution_context_identity_sha256"),
      `${definition} must require execution context`,
    );
    assert.deepEqual(
      schema.$defs[definition].properties.execution_context_identity_sha256,
      { $ref: "#/$defs/sha256" },
      `${definition} must bind a SHA-256 context identity`,
    );
  }
});

test("strict path grammar accepts canonical allowlist syntax", () => {
  assert.equal(normalizeRepositoryRelativePath("src/path-containment.mjs"), "src/path-containment.mjs");
  assert.equal(normalizeRepositoryRelativePath(".gitignore"), ".gitignore");
});

test("strict path grammar rejects separator, traversal, aliases, devices, ADS, and wildcards", () => {
  const cases = [
    ["src\\path-containment.mjs", "PATH_SEPARATOR_NOT_CANONICAL"],
    ["../outside.mjs", "PATH_TRAVERSAL_PROHIBITED"],
    ["src/../outside.mjs", "PATH_TRAVERSAL_PROHIBITED"],
    ["src/.git/config", "DIRECT_GIT_PATH_PROHIBITED"],
    ["src/FILE~1.MJS", "PATH_SHORT_NAME_ALIAS_PROHIBITED"],
    ["src/con.mjs", "PATH_RESERVED_DEVICE_NAME_PROHIBITED"],
    ["src/file.mjs:stream", "PATH_ALTERNATE_DATA_STREAM_PROHIBITED"],
    ["src/file*.mjs", "PATH_WILDCARD_PROHIBITED"],
    ["src/file.mjs.", "PATH_TRAILING_DOT_OR_SPACE_PROHIBITED"],
    ["//server/share/file.mjs", "PATH_UNC_PROHIBITED"],
  ];
  for (const [candidate, code] of cases) {
    expectAuthorityError(() => normalizeRepositoryRelativePath(candidate), code);
  }
});

test("task bindings retain the concrete predecessor commit", () => {
  const authority = loadAuthority();
  const registration = registrationFixture(authority);
  validateRegistrationRecord(registration, authority, { now: new Date("2026-07-29T01:00:00Z") });
  const concreteBaseline = "d".repeat(40);
  const concreteBaselineTree = "e".repeat(40);
  const preauthorization = createTaskPreauthorization(
    authority,
    registration,
    authority.tasks[1].task_id,
    concreteBaseline,
    concreteBaselineTree,
  );
  const binding = createPreauthorizedTaskBinding(authority, registration, preauthorization);
  assert.equal(preauthorization.baseline_commit, concreteBaseline);
  assert.equal(preauthorization.baseline_tree, concreteBaselineTree);
  assert.equal(binding.baseline_commit, concreteBaseline);
  assert.equal(binding.baseline_tree, concreteBaselineTree);
  assert.equal(binding.approved_candidate_set_identity_sha256s.length, 2);
  assert.equal(binding.disposition, "PREAUTHORIZED");
  assert.equal(binding.mission_authority_added, false);
});

test("canonical approved candidate sets bind task path iteration baseline and preauthorization", () => {
  const authority = loadAuthority();
  const registration = registrationFixture(authority);
  for (const task of authority.tasks) {
    const preauthorization = createTaskPreauthorization(authority, registration, task.task_id);
    const binding = createPreauthorizedTaskBinding(authority, registration, preauthorization);
    for (const template of task.approved_builder_candidate_sets) {
      const candidateSet = createApprovedBuilderCandidateSet(
        authority,
        registration,
        task,
        preauthorization,
        template.iteration,
        template.repository_relative_path,
      );
      assert.equal(
        validateApprovedBuilderCandidateSet(
          authority,
          registration,
          task,
          preauthorization,
          candidateSet,
          { now: new Date("2026-07-29T01:00:00Z") },
        ).valid,
        true,
      );
      assert.equal(candidateSet.task_id, task.task_id);
      assert.equal(candidateSet.iteration, template.iteration);
      assert.equal(candidateSet.repository_relative_path, task.authorized_source_paths[0]);
      assert.ok(binding.approved_candidate_set_identity_sha256s.includes(candidateSet.candidate_set_identity_sha256));
    }
  }
});

test("preauthorization tampering cannot create a binding", () => {
  const authority = loadAuthority();
  const registration = registrationFixture(authority);
  const preauthorization = createTaskPreauthorization(authority, registration, authority.tasks[0].task_id);
  preauthorization.maximum_iterations = 4;
  expectAuthorityError(
    () => createPreauthorizedTaskBinding(authority, registration, preauthorization),
    "PREAUTHORIZATION_TEMPLATE_MISMATCH",
    "TIM_REQUIRED",
  );
});

test("attempt four fails before a worker run can be authorized", () => {
  const authority = loadAuthority();
  const task = authority.tasks[0];
  const prior = [1, 2, 3].map((iteration) => ({ iteration }));
  expectAuthorityError(
    () => authorizeBuilderIteration(authority, task, prior, 4),
    "ITERATION_LIMIT_EXHAUSTED",
    "EXHAUSTED",
  );
});

test("only closed state transitions are accepted", () => {
  const authority = loadAuthority();
  assert.equal(transitionIteration(authority, "PLANNED", "PREAUTHORIZED"), "PREAUTHORIZED");
  expectAuthorityError(
    () => transitionIteration(authority, "PLANNED", "ADMITTED"),
    "ITERATION_TRANSITION_INVALID",
  );
});

test("authority tampering is rejected instead of normalized", () => {
  const authority = structuredClone(loadAuthority());
  authority.limits.maximum_builder_iterations_per_task = 4;
  expectAuthorityError(() => validateAuthority(authority), "AUTHORITY_EXACT_IDENTITY_CHANGED", "TIM_REQUIRED");
  assert.notEqual(canonicalJson(authority), canonicalJson(loadAuthority()));
});
