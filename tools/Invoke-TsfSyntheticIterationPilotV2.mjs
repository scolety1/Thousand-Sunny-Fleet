#!/usr/bin/env node

import {
  applyPersistedReplacementForInterruption,
  archiveFixtureForFreshProof,
  loadAuthority,
  resumePersistedTask,
  runCanonicalPostmergePilot,
  runThreeTaskPilot,
  validateAuthority,
} from "./hq-dispatch/v1/synthetic-iteration-authority-v2.mjs";

function usage() {
  process.stderr.write(
    "Usage: node tools/Invoke-TsfSyntheticIterationPilotV2.mjs <validate|pilot|canonical-postmerge-pilot|archive-and-pilot|archive-and-replay> [label]\n"
      + "       node tools/Invoke-TsfSyntheticIterationPilotV2.mjs <apply-and-crash|resume-task> <evidence-root> <task-id> <iteration>\n",
  );
}

function labelOrDefault(prefix) {
  const supplied = process.argv[3];
  if (supplied) {
    if (!/^[a-z0-9][a-z0-9-]{2,80}$/.test(supplied)) throw new Error("LABEL_INVALID");
    return supplied;
  }
  return `${prefix}-${new Date().toISOString().replaceAll(/[:.]/g, "-").toLowerCase()}`;
}

try {
  const command = process.argv[2];
  const authority = loadAuthority();
  if (command === "validate") {
    process.stdout.write(`${JSON.stringify(validateAuthority(authority), null, 2)}\n`);
  } else if (command === "pilot") {
    const result = runThreeTaskPilot({
      authority,
      evidenceLabel: labelOrDefault("working-tree"),
      allowDirtyTsfCandidate: true,
    });
    process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  } else if (command === "canonical-postmerge-pilot") {
    const result = runCanonicalPostmergePilot({
      authority,
      evidenceLabel: labelOrDefault("canonical-postmerge"),
    });
    process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  } else if (command === "archive-and-pilot") {
    const label = labelOrDefault("working-tree");
    const archive = archiveFixtureForFreshProof(`${label}-prior`, authority);
    const replay = runThreeTaskPilot({
      authority,
      evidenceLabel: label,
      allowDirtyTsfCandidate: true,
    });
    process.stdout.write(`${JSON.stringify({ archive, replay }, null, 2)}\n`);
  } else if (command === "archive-and-replay") {
    const label = labelOrDefault("exact-candidate");
    const archive = archiveFixtureForFreshProof(`${label}-prior`, authority);
    const replay = runThreeTaskPilot({ authority, evidenceLabel: label });
    process.stdout.write(`${JSON.stringify({ archive, replay }, null, 2)}\n`);
  } else if (command === "apply-and-crash") {
    const evidenceRoot = process.argv[3];
    const taskId = process.argv[4];
    const iteration = Number.parseInt(process.argv[5], 10);
    const replacement = applyPersistedReplacementForInterruption(evidenceRoot, taskId, iteration);
    process.stdout.write(`${JSON.stringify({
      disposition: "TEST_ONLY_WRITER_TERMINATED_AFTER_REPLACEMENT",
      replacement,
      exit_code: 86,
    })}\n`);
    process.exitCode = 86;
  } else if (command === "resume-task") {
    const evidenceRoot = process.argv[3];
    const taskId = process.argv[4];
    const iteration = Number.parseInt(process.argv[5], 10);
    const result = resumePersistedTask(evidenceRoot, taskId, iteration);
    process.stdout.write(`${JSON.stringify({
      disposition: "EXACT_PERSISTED_RECOVERY_CONTINUED",
      task_id: result.task_id,
      iteration: result.iteration,
      commit: result.commit_receipt.commit,
      admission: result.admission.disposition,
      continuation_result_identity_sha256: result.continuation_result_identity_sha256,
    })}\n`);
  } else {
    usage();
    process.exitCode = 2;
  }
} catch (error) {
  process.stderr.write(`${JSON.stringify({
    verdict: "RED",
    name: error?.name ?? "Error",
    code: error?.code ?? "UNCLASSIFIED_ERROR",
    disposition: error?.disposition ?? "BLOCKED",
    message: error?.message ?? String(error),
    details: error?.details ?? {},
    stack: error?.stack ?? "",
  }, null, 2)}\n`);
  process.exitCode = 1;
}
