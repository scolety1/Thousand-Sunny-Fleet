import test from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";

import {
  AuthorityV2Error,
  TSF_ROOT,
  inspectCanonicalPostmergePilotExecutionContext,
  loadAuthority,
  runCanonicalPostmergePilot,
  runThreeTaskPilot,
  validateSyntheticPilotExecutionContext,
} from "../tools/hq-dispatch/v1/synthetic-iteration-authority-v2.mjs";

const authority = loadAuthority();
const candidate = authority.pilot_execution_contexts.contexts.EXACT_CANDIDATE;
const postmerge = authority.pilot_execution_contexts.contexts.EXACT_CANONICAL_POSTMERGE;

function git(...args) {
  return execFileSync(
    authority.executables.git.path,
    [
      "-c", "credential.helper=",
      "-c", "core.hooksPath=NUL",
      "-c", `safe.directory=${TSF_ROOT.replaceAll("\\", "/")}`,
      "-C", TSF_ROOT,
      ...args,
    ],
    {
      encoding: "utf8",
      env: {
        SystemRoot: process.env.SystemRoot,
        ComSpec: process.env.ComSpec,
        TEMP: process.env.TEMP,
        TMP: process.env.TMP,
        GIT_CONFIG_NOSYSTEM: "1",
        GIT_CONFIG_GLOBAL: "NUL",
      },
      windowsHide: true,
    },
  ).trim();
}

function candidateObservation(overrides = {}) {
  return {
    repository_root: TSF_ROOT,
    git_top_level: TSF_ROOT,
    head: candidate.candidate_head,
    tree: candidate.candidate_tree,
    current_head_subject: candidate.reviewed_source_subject,
    branch: null,
    detached: true,
    clean: true,
    working_tree_status: [],
    ordered_parents: [candidate.candidate_parent],
    parent_count: 1,
    first_parent_tree: git("rev-parse", `${candidate.candidate_parent}^{tree}`),
    second_parent_tree: null,
    second_parent_subject: null,
    source_contained: false,
    base_to_head_commits: [candidate.candidate_head],
    source_to_head_commits: [],
    pr_number: null,
    pr_state: null,
    pr_merge_commit: null,
    github_merged_at: null,
    ...overrides,
  };
}

function postmergeObservation(overrides = {}) {
  return {
    repository_root: postmerge.validation_repository_root,
    git_top_level: postmerge.validation_repository_root,
    head: postmerge.canonical_merge_head,
    tree: postmerge.merge_tree,
    current_head_subject: postmerge.canonical_merge_subject,
    branch: null,
    detached: true,
    clean: true,
    working_tree_status: [],
    ordered_parents: [postmerge.first_parent, postmerge.second_parent],
    parent_count: 2,
    first_parent_tree: git("rev-parse", `${postmerge.first_parent}^{tree}`),
    second_parent_tree: postmerge.reviewed_source_tree,
    second_parent_subject: postmerge.reviewed_source_subject,
    source_contained: true,
    base_to_head_commits: [],
    source_to_head_commits: [postmerge.canonical_merge_head],
    pr_number: postmerge.pr_number,
    pr_state: postmerge.pr_state,
    pr_merge_commit: postmerge.canonical_merge_head,
    github_merged_at: postmerge.github_merged_at,
    ...overrides,
  };
}

function expectCode(fn, code, disposition = "BLOCKED") {
  assert.throws(fn, (error) => {
    assert.ok(error instanceof AuthorityV2Error);
    assert.equal(error.code, code);
    assert.equal(error.disposition, disposition);
    return true;
  });
}

test("candidate and canonical post-merge identities are distinct exact contracts", () => {
  assert.notEqual(candidate.context_identity_sha256, postmerge.context_identity_sha256);
  assert.equal(candidate.candidate_tree, postmerge.merge_tree);
  assert.equal(postmerge.reviewed_source_tree, postmerge.merge_tree);
  assert.notEqual(postmerge.canonical_merge_subject, postmerge.reviewed_source_subject);
  assert.equal(postmerge.reviewed_source_head, postmerge.second_parent);
});

test("candidate behavior remains exact and accepts only its historical compatibility states", () => {
  const exact = validateSyntheticPilotExecutionContext(
    authority,
    "EXACT_CANDIDATE",
    candidateObservation(),
  );
  assert.equal(exact.execution_context, "EXACT_CANDIDATE");
  assert.equal(exact.current_head_subject, candidate.reviewed_source_subject);
  assert.equal(exact.merge_subject, null);

  const dirtyExpectedBranch = candidateObservation({
    branch: candidate.expected_branch,
    detached: false,
    clean: false,
    working_tree_status: ["1 .M N... synthetic compatibility fixture"],
  });
  assert.equal(
    validateSyntheticPilotExecutionContext(
      authority,
      "EXACT_CANDIDATE",
      dirtyExpectedBranch,
      { allowDirtyCandidate: true },
    ).clean,
    false,
  );
  expectCode(
    () => validateSyntheticPilotExecutionContext(
      authority,
      "EXACT_CANDIDATE",
      { ...dirtyExpectedBranch, branch: "work/untrusted" },
      { allowDirtyCandidate: true },
    ),
    "TSF_CANDIDATE_BRANCH_STATE_CHANGED",
  );
});

test("actual immutable Git objects satisfy the canonical post-merge tuple", () => {
  assert.equal(git("rev-parse", `${postmerge.canonical_merge_head}^{tree}`), postmerge.merge_tree);
  assert.equal(
    git("show", "-s", "--format=%P", postmerge.canonical_merge_head),
    `${postmerge.first_parent} ${postmerge.second_parent}`,
  );
  assert.equal(
    git("show", "-s", "--format=%s", postmerge.canonical_merge_head),
    postmerge.canonical_merge_subject,
  );
  assert.equal(
    git("show", "-s", "--format=%s", postmerge.reviewed_source_head),
    postmerge.reviewed_source_subject,
  );

  const exact = validateSyntheticPilotExecutionContext(
    authority,
    "EXACT_CANONICAL_POSTMERGE",
    postmergeObservation(),
  );
  assert.equal(exact.execution_context, "EXACT_CANONICAL_POSTMERGE");
  assert.equal(exact.current_head, postmerge.canonical_merge_head);
  assert.equal(exact.current_head_subject, postmerge.canonical_merge_subject);
  assert.equal(exact.reviewed_source_subject, postmerge.reviewed_source_subject);
  assert.deepEqual(exact.ordered_parents, [postmerge.first_parent, postmerge.second_parent]);
  assert.equal(exact.pr_identity.number, 24);
  assert.equal(exact.pr_identity.state, "MERGED");
  assert.equal(exact.tree_equivalent, true);
  assert.equal(exact.source_contained, true);
  assert.equal(exact.no_unrelated_commits, true);
});

test("closed post-merge adapter inspects the pinned detached control worktree", () => {
  const exact = inspectCanonicalPostmergePilotExecutionContext({ authority });
  assert.equal(exact.execution_context, "EXACT_CANONICAL_POSTMERGE");
  assert.equal(exact.repository_root, postmerge.validation_repository_root);
  assert.equal(
    exact.git_top_level.replaceAll("/", "\\"),
    postmerge.validation_repository_root,
  );
  assert.equal(exact.current_head, postmerge.canonical_merge_head);
  assert.equal(exact.current_tree, postmerge.merge_tree);
  assert.equal(exact.detached, true);
  assert.equal(exact.clean, true);
  assert.equal(exact.current_head_subject, postmerge.canonical_merge_subject);
  assert.equal(exact.reviewed_source_subject, postmerge.reviewed_source_subject);
});

test("canonical post-merge validation rejects identity, topology, provenance, and state substitutions", () => {
  const cases = [
    [{ head: "d".repeat(40) }, "TSF_POSTMERGE_HEAD_CHANGED"],
    [{ tree: "f".repeat(40) }, "TSF_POSTMERGE_TREE_CHANGED"],
    [{ current_head_subject: postmerge.reviewed_source_subject }, "TSF_POSTMERGE_MERGE_SUBJECT_CHANGED"],
    [{ parent_count: 1, ordered_parents: [postmerge.first_parent] }, "TSF_POSTMERGE_PARENT_COUNT_CHANGED"],
    [{ ordered_parents: [postmerge.second_parent, postmerge.first_parent] }, "TSF_POSTMERGE_FIRST_PARENT_CHANGED"],
    [{ ordered_parents: ["c".repeat(40), postmerge.second_parent] }, "TSF_POSTMERGE_FIRST_PARENT_CHANGED"],
    [{ ordered_parents: [postmerge.first_parent, candidate.candidate_parent] }, "TSF_POSTMERGE_SECOND_PARENT_CHANGED"],
    [{ second_parent_tree: "e".repeat(40) }, "TSF_POSTMERGE_SOURCE_TREE_CHANGED"],
    [{ second_parent_subject: "feat: substituted source" }, "TSF_POSTMERGE_SOURCE_SUBJECT_CHANGED"],
    [{ source_contained: false }, "TSF_POSTMERGE_SOURCE_NOT_CONTAINED"],
    [{
      source_to_head_commits: [postmerge.canonical_merge_head, "d".repeat(40)],
    }, "TSF_POSTMERGE_UNRELATED_DESCENDANT_PRESENT"],
    [{ pr_number: 25 }, "TSF_POSTMERGE_PR_NUMBER_CHANGED"],
    [{ pr_state: "OPEN" }, "TSF_POSTMERGE_PR_NOT_MERGED"],
    [{ pr_merge_commit: candidate.candidate_head }, "TSF_POSTMERGE_PR_MERGE_COMMIT_CHANGED"],
    [{ github_merged_at: "2026-07-30T01:27:36Z" }, "TSF_POSTMERGE_PR_MERGED_AT_CHANGED"],
    [{ branch: "main", detached: false }, "TSF_POSTMERGE_WORKTREE_STATE_CHANGED"],
    [{ clean: false, working_tree_status: ["1 .M N... hotfix"] }, "TSF_POSTMERGE_NOT_CLEAN"],
    [{ base_to_head_commits: [candidate.candidate_head] }, "TSF_POSTMERGE_CANDIDATE_DISTANCE_EVIDENCE_PRESENT"],
  ];
  for (const [overrides, code] of cases) {
    expectCode(
      () => validateSyntheticPilotExecutionContext(
        authority,
        "EXACT_CANONICAL_POSTMERGE",
        postmergeObservation(overrides),
      ),
      code,
    );
  }
});

test("candidate and post-merge evidence cannot be replayed across contexts", () => {
  expectCode(
    () => validateSyntheticPilotExecutionContext(
      authority,
      "EXACT_CANDIDATE",
      postmergeObservation(),
    ),
    "TSF_EXECUTION_CONTEXT_ROOT_MISMATCH",
  );
  expectCode(
    () => validateSyntheticPilotExecutionContext(
      authority,
      "EXACT_CANONICAL_POSTMERGE",
      candidateObservation(),
    ),
    "TSF_EXECUTION_CONTEXT_ROOT_MISMATCH",
  );
});

test("callers cannot substitute an execution context or enable dirty post-merge mode", () => {
  expectCode(
    () => runThreeTaskPilot({ executionContext: "EXACT_CANONICAL_POSTMERGE" }),
    "PILOT_CALLER_CONTEXT_SUBSTITUTION",
    "TIM_REQUIRED",
  );
  expectCode(
    () => runCanonicalPostmergePilot({ allowDirtyTsfCandidate: true }),
    "PILOT_CALLER_CONTEXT_SUBSTITUTION",
    "TIM_REQUIRED",
  );
  expectCode(
    () => validateSyntheticPilotExecutionContext(
      authority,
      "CALLER_SELECTED",
      postmergeObservation(),
    ),
    "PILOT_EXECUTION_CONTEXT_UNKNOWN",
    "TIM_REQUIRED",
  );
});
